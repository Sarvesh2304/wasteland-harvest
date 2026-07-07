extends "res://tests/test_case.gd"
## Placeholder test proving the headless test harness runs end-to-end (Phase 1 scaffolding).
## Replace/extend once real systems (farming, inventory, NPCs, etc.) exist in later phases.


func test_harness_runs() -> void:
	assert_eq(1 + 1, 2, "sanity check")
	assert_true(true, "trivially true")
