extends "res://tests/test_case.gd"
## DayManager time-progression math, clock formatting, and sky-color gradient (Phase 2).
## Instantiates the autoload's script directly (autoloads don't exist under the headless
## test runner's SceneTree), so everything here is pure logic — no rendered scene needed.

const DayManagerScript := preload("res://scripts/day_manager.gd")


func _make_dm():
	return DayManagerScript.new()


func test_initial_state() -> void:
	var dm = _make_dm()
	assert_eq(dm.day, 1, "game starts on day 1")
	assert_eq(dm.clock_text(), "6:00 AM", "day starts at 6:00 AM")
	dm.free()


func test_real_seconds_advance_clock() -> void:
	# 1 in-game minute per real second: simulate 90 frames of 1.0s deltas via the same
	# math _process uses.
	var dm = _make_dm()
	for i in 90:
		dm.advance_minutes(1.0 * DayManagerScript.GAME_MINUTES_PER_REAL_SECOND)
	assert_eq(dm.clock_text(), "7:30 AM", "90 real seconds = 90 game minutes")
	assert_eq(dm.day, 1, "still the same day")
	dm.free()


func test_fractional_deltas_accumulate() -> void:
	# 600 frames at 1/60s each = 10 real seconds = 10 game minutes (within float epsilon —
	# the displayed clock floors, so it may legitimately read 6:09 when the sum lands a hair
	# under 10.0).
	var dm = _make_dm()
	for i in 600:
		dm.advance_minutes((1.0 / 60.0) * DayManagerScript.GAME_MINUTES_PER_REAL_SECOND)
	var expected := float(DayManagerScript.DAY_START_MINUTES) + 10.0
	assert_true(absf(dm.minutes_into_day - expected) < 0.001,
		"fractional frame deltas accumulate to ~10 minutes (got %f)" % dm.minutes_into_day)
	dm.free()


func test_midnight_rolls_day_counter() -> void:
	var dm = _make_dm()
	var days_started: Array[int] = []
	dm.day_started.connect(func(d: int) -> void: days_started.append(d))
	# From 6:00 AM, midnight is 18 game hours away.
	dm.advance_minutes(18 * 60 + 5)
	assert_eq(dm.day, 2, "clock crossed midnight")
	assert_eq(dm.clock_text(), "12:05 AM")
	assert_eq(days_started, [2], "day_started emitted once with the new day")
	dm.free()


func test_multi_day_advance_in_one_step() -> void:
	var dm = _make_dm()
	dm.advance_minutes(2 * DayManagerScript.MINUTES_PER_DAY)
	assert_eq(dm.day, 3, "two full days advance the counter twice")
	assert_eq(dm.clock_text(), "6:00 AM", "time of day unchanged after whole days")
	dm.free()


func test_clock_formatting() -> void:
	assert_eq(DayManagerScript.format_clock(0), "12:00 AM", "midnight")
	assert_eq(DayManagerScript.format_clock(359), "5:59 AM")
	assert_eq(DayManagerScript.format_clock(720), "12:00 PM", "noon")
	assert_eq(DayManagerScript.format_clock(750), "12:30 PM")
	assert_eq(DayManagerScript.format_clock(13 * 60), "1:00 PM")
	assert_eq(DayManagerScript.format_clock(1439), "11:59 PM")


func test_sky_color_keyframes() -> void:
	var night: Color = DayManagerScript.SKY_KEYFRAMES[0][1]
	assert_eq(DayManagerScript.sky_color(0.0), night, "midnight is full night")
	assert_eq(DayManagerScript.sky_color(3 * 60.0), night, "3 AM sits in the flat night segment")
	assert_eq(DayManagerScript.sky_color(12 * 60.0), Color(1, 1, 1), "noon is unmodulated white")


func test_sky_color_transitions() -> void:
	var night: Color = DayManagerScript.sky_color(0.0)
	var dawn: Color = DayManagerScript.sky_color(6.5 * 60.0)
	var mid_dawn: Color = DayManagerScript.sky_color(5.75 * 60.0)  # halfway 5:00 -> 6:30
	assert_true(mid_dawn.r > night.r and mid_dawn.r < dawn.r,
		"dawn transition interpolates between night and dawn")
	# Dusk (6:30 PM) should carry the game's amber identity: strongly warm.
	var dusk: Color = DayManagerScript.sky_color(18.5 * 60.0)
	assert_true(dusk.r > dusk.b, "dusk is warm (red over blue)")
	# After nightfall completes (8:30 PM), the color holds at night through midnight (the
	# gradient wraps 20.5 -> 24.0 between two identical night colors).
	assert_eq(DayManagerScript.sky_color(22 * 60.0), night, "late evening is full night")
	assert_eq(DayManagerScript.sky_color(23.99 * 60.0), night, "just before midnight wraps cleanly")


func test_sky_color_wraps_past_one_day() -> void:
	assert_eq(DayManagerScript.sky_color(1440.0 + 720.0), DayManagerScript.sky_color(720.0),
		"minutes beyond one day wrap around")


func test_time_pause_blocks_advancement() -> void:
	var dm = _make_dm()
	dm.time_paused = true
	dm._process(5.0)
	assert_eq(dm.clock_text(), "6:00 AM", "paused clock does not advance via _process")
	dm.free()
