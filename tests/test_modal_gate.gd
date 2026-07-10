extends "res://tests/test_case.gd"
## Phase 6 modal mutual-exclusion registry (scripts/modal_gate.gd) — the pure any_open() core
## plus the thin register/is_any_open instance wrapper around it. Same "pure core,
## headless-testable" split as tests/test_shop_db.gd / tests/test_build_grid.gd. The live wiring
## (builder.gd refusing build_toggle mid-dialogue, the open_*() guards) is exercised end-to-end
## by tools/soak_test.gd against the real scene; these tests pin the decision logic itself.

const ModalGate := preload("res://scripts/modal_gate.gd")


## Minimal stand-in for a modal surface: anything exposing a boolean `active` property, which is
## exactly (and only) what the gate reads off the real builder/dialogue/store/shipping nodes.
class StubSurface:
	var active := false


## A deliberately `active`-less object, for the missing-property defensive path.
class NoActiveField:
	var something_else := true


func test_any_open_false_for_empty_list() -> void:
	assert_false(ModalGate.any_open([]))


func test_any_open_false_when_all_surfaces_inactive() -> void:
	assert_false(ModalGate.any_open([StubSurface.new(), StubSurface.new()]))


func test_any_open_true_when_one_surface_is_active() -> void:
	var a := StubSurface.new()
	var b := StubSurface.new()
	b.active = true
	assert_true(ModalGate.any_open([a, b]))


func test_any_open_exempt_skips_only_that_surface() -> void:
	var a := StubSurface.new()
	a.active = true
	assert_false(ModalGate.any_open([a], a),
		"a surface's own active state must never veto its own toggle")
	var b := StubSurface.new()
	b.active = true
	assert_true(ModalGate.any_open([a, b], a),
		"another open surface still blocks even when the asker is exempt")


func test_any_open_ignores_null_entries() -> void:
	var a := StubSurface.new()
	a.active = true
	assert_false(ModalGate.any_open([null, null]))
	assert_true(ModalGate.any_open([null, a]))


func test_any_open_object_without_active_property_reads_as_closed() -> void:
	assert_false(ModalGate.any_open([NoActiveField.new()]),
		"a surface with no `active` property must read as not-open, not error")


func test_any_open_freed_object_reads_as_closed() -> void:
	# The real surfaces are Nodes that die with the main scene while the gate could briefly
	# outlive them during teardown — a freed entry must be skipped, never dereferenced.
	var node := Node.new()
	node.set("active", true)  # no-op on a plain Node, but documents intent
	var surfaces: Array = [node]
	node.free()
	assert_false(ModalGate.any_open(surfaces))


func test_register_and_is_any_open_wrapper() -> void:
	var gate: ModalGate = ModalGate.new()
	var a := StubSurface.new()
	var b := StubSurface.new()
	gate.register(a)
	gate.register(b)
	assert_false(gate.is_any_open())
	a.active = true
	assert_true(gate.is_any_open())
	assert_false(gate.is_any_open_except(a),
		"the only open surface being the asker itself means nothing ELSE is open")
	assert_true(gate.is_any_open_except(b))


func test_register_is_idempotent_and_ignores_null() -> void:
	var gate: ModalGate = ModalGate.new()
	var a := StubSurface.new()
	gate.register(a)
	gate.register(a)
	gate.register(null)
	a.active = true
	assert_true(gate.is_any_open())
	assert_false(gate.is_any_open_except(a),
		"double-registration must not make a surface block itself via its duplicate")


func test_gate_mirrors_the_real_build_toggle_mid_dialogue_scenario() -> void:
	# The literal shape of the fixed bug, in miniature: dialogue open, build mode asks to turn
	# on (blocked), dialogue closes, build mode asks again (allowed), and while build mode is on
	# the dialogue's own open-check is blocked in return.
	var gate: ModalGate = ModalGate.new()
	var dialogue := StubSurface.new()
	var build_mode := StubSurface.new()
	gate.register(dialogue)
	gate.register(build_mode)
	dialogue.active = true
	assert_true(gate.is_any_open_except(build_mode), "build mode is refused mid-dialogue")
	dialogue.active = false
	assert_false(gate.is_any_open_except(build_mode), "build mode is allowed once dialogue closes")
	build_mode.active = true
	assert_true(gate.is_any_open_except(dialogue), "and dialogue is refused mid-build in reverse")
