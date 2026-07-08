extends "res://tests/test_case.gd"
## Pure selection-index math for scenes/settlement_select.tscn (ROADMAP.md Phase 4): cycling
## through the 3 settlement options wraps in both directions without needing a live Control node.

const SettlementSelect := preload("res://scripts/settlement_select.gd")


func test_wrap_forward() -> void:
	assert_eq(SettlementSelect.wrap_index(0, 1, 3), 1)
	assert_eq(SettlementSelect.wrap_index(1, 1, 3), 2)
	assert_eq(SettlementSelect.wrap_index(2, 1, 3), 0, "wraps forward past the last option")


func test_wrap_backward() -> void:
	assert_eq(SettlementSelect.wrap_index(0, -1, 3), 2, "wraps backward past the first option")
	assert_eq(SettlementSelect.wrap_index(2, -1, 3), 1)
	assert_eq(SettlementSelect.wrap_index(1, -1, 3), 0)


func test_wrap_zero_count_is_safe() -> void:
	assert_eq(SettlementSelect.wrap_index(0, 1, 0), 0)
