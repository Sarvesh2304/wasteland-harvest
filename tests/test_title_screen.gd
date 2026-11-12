extends "res://tests/test_case.gd"
## scripts/title_screen.gd's pure display/navigation math (2026-07-11 title screen): menu
## composition, the documented slot auto-naming row format, the last-played date line, and the
## windowed-list scroll clamp — all static, no Control/scene required, the same split
## settlement_select.gd's wrap_index established.

const TitleScreen := preload("res://scripts/title_screen.gd")


func test_menu_entries_with_and_without_slots() -> void:
	assert_eq(TitleScreen.menu_entries(true), ["New Game", "Load Game", "Options", "Exit"])
	assert_eq(TitleScreen.menu_entries(false), ["New Game", "Options", "Exit"],
		"Load Game is hidden entirely on a first launch with nothing to load")


func test_format_slot_row_auto_naming_scheme() -> void:
	assert_eq(TitleScreen.format_slot_row(
		{"slot_id": 3, "settlement_name": "Forest Edge", "day": 12}),
		"3. Forest Edge — Day 12")
	assert_eq(TitleScreen.format_slot_row({}), "0.  — Day 1", "missing fields never crash a row")


func test_format_saved_date() -> void:
	assert_eq(TitleScreen.format_saved_date(0), "", "pre-timestamp saves show no fake date")
	assert_eq(TitleScreen.format_saved_date(-5), "")
	assert_eq(TitleScreen.format_saved_date(864000), "Last played 1970-01-11")


func test_scroll_start_short_lists_never_scroll() -> void:
	for selected in 6:
		assert_eq(TitleScreen.scroll_start(selected, 6, 6), 0)
	assert_eq(TitleScreen.scroll_start(0, 0, 6), 0, "empty list is safe")


func test_scroll_start_centers_and_clamps() -> void:
	assert_eq(TitleScreen.scroll_start(0, 10, 6), 0, "clamped at the top")
	assert_eq(TitleScreen.scroll_start(5, 10, 6), 2, "selection centered mid-list")
	assert_eq(TitleScreen.scroll_start(9, 10, 6), 4, "clamped at the bottom")
	for selected in 10:
		var start := TitleScreen.scroll_start(selected, 10, 6)
		assert_true(selected >= start and selected < start + 6,
			"selection %d stays inside the visible window" % selected)
