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
	# Stardew pace (2026-10-07): 10 game minutes per 7 real seconds — so 63 real seconds of
	# 1.0s deltas (via the same math _process uses) is exactly 90 game minutes.
	var dm = _make_dm()
	for i in 63:
		dm.advance_minutes(1.0 * DayManagerScript.GAME_MINUTES_PER_REAL_SECOND)
	assert_eq(dm.clock_text(), "7:30 AM", "63 real seconds = 90 game minutes")
	assert_eq(dm.day, 1, "still the same day")
	dm.free()


func test_waking_day_lasts_about_fourteen_real_minutes() -> void:
	var real_seconds := (20.0 * 60.0) / DayManagerScript.GAME_MINUTES_PER_REAL_SECOND
	assert_true(absf(real_seconds - 840.0) < 0.01, "6 AM to 2 AM = 840 real seconds (got %f)" % real_seconds)


func test_fractional_deltas_accumulate() -> void:
	# 420 frames at 1/60s each = 7 real seconds = 10 game minutes (within float epsilon).
	var dm = _make_dm()
	for i in 420:
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


func test_skip_to_next_morning() -> void:
	# Phase 3's pass-out transition (player.gd._pass_out): jumps straight to 6:00 AM the next
	# day, mid-afternoon or not, and fires day_started so crop growth ticks exactly like a
	## natural midnight rollover would.
	var dm = _make_dm()
	dm.advance_minutes(8 * 60)  # 2:00 PM
	var days_started: Array[int] = []
	dm.day_started.connect(func(d: int) -> void: days_started.append(d))
	dm.skip_to_next_morning()
	assert_eq(dm.day, 2, "day counter advances by exactly one")
	assert_eq(dm.clock_text(), "6:00 AM", "wakes at 6:00 AM regardless of when blackout happened")
	assert_eq(days_started, [2], "day_started fires so growth/other daily systems still tick")
	dm.free()


## -- 2026-07-11 forced-sleep session: the after-midnight morning-skip fix + the late-night
##    window (see skip_to_next_morning's doc comment for the double-tick bug this pins) --

func test_skip_after_midnight_does_not_add_a_second_day() -> void:
	# Stay up past midnight (the natural rollover increments the day and fires day_started),
	# then end the night at 1:00 AM: the player wakes at 6 AM of the day that ALREADY started —
	# no second increment, and critically no second day_started (crops must not grow twice for
	# one night).
	var dm = _make_dm()
	var days_started: Array[int] = []
	dm.day_started.connect(func(d: int) -> void: days_started.append(d))
	dm.advance_minutes(19 * 60)  # 6:00 AM day 1 -> 1:00 AM day 2
	assert_eq(dm.day, 2, "midnight rollover reached day 2")
	assert_eq(days_started, [2], "the rollover itself fired day_started")
	dm.skip_to_next_morning()
	assert_eq(dm.day, 2, "an after-midnight sleep wakes on the SAME calendar day")
	assert_eq(dm.clock_text(), "6:00 AM", "at 6:00 AM")
	assert_eq(days_started, [2], "day_started did NOT fire a second time for the same night")
	dm.free()


func test_morning_skip_adds_day_boundaries() -> void:
	assert_false(DayManagerScript.morning_skip_adds_day(0.0),
		"a midnight ending is after the rollover — no extra day")
	assert_false(DayManagerScript.morning_skip_adds_day(2 * 60.0),
		"the 2 AM forced pass-out must not skip a day")
	assert_false(DayManagerScript.morning_skip_adds_day(359.9),
		"just before 6 AM still belongs to the already-rolled night")
	assert_true(DayManagerScript.morning_skip_adds_day(float(DayManagerScript.DAY_START_MINUTES)),
		"exactly 6:00 AM (a just-woken clock) sleeps into a NEW day")
	assert_true(DayManagerScript.morning_skip_adds_day(14 * 60.0),
		"an afternoon blackout sleeps into a new day, as always")
	assert_true(DayManagerScript.morning_skip_adds_day(23.9 * 60.0),
		"just before midnight sleeps into a new day, as always")


func test_time_advanced_emitted_only_for_lived_time() -> void:
	# The night rules (player.gd) ride time_advanced precisely because sleep transitions and
	# teleports must never read as time spent awake — pin the emission contract both ways.
	var dm = _make_dm()
	var emissions: Array = []
	dm.time_advanced.connect(func(prev: float, new: float) -> void:
		emissions.append([prev, new]))
	dm.advance_minutes(30.0)
	assert_eq(emissions.size(), 1, "advance_minutes emits time_advanced")
	assert_eq(emissions[0], [360.0, 390.0], "with the exact lived-through interval")
	dm.skip_to_next_morning()
	assert_eq(emissions.size(), 1,
		"skip_to_next_morning is a transition, not lived time — no time_advanced")
	dm.minutes_into_day = 100.0  # a direct teleport (save-load shape) emits nothing either
	assert_eq(emissions.size(), 1, "teleporting the clock emits no time_advanced")
	dm.advance_minutes(1.0)
	assert_eq(emissions[1], [100.0, 101.0],
		"the next lived tick integrates from the teleported position")
	dm.free()


func test_is_late_night_window() -> void:
	assert_true(DayManagerScript.is_late_night(0.0), "midnight opens the sleepy window")
	assert_true(DayManagerScript.is_late_night(2 * 60.0), "2 AM is late night")
	assert_true(DayManagerScript.is_late_night(359.9), "just before 6 AM is still late night")
	assert_false(DayManagerScript.is_late_night(float(DayManagerScript.DAY_START_MINUTES)),
		"6:00 AM exactly is morning — every sleep transition lands here, outside the window")
	assert_false(DayManagerScript.is_late_night(720.0), "noon is not late night")
	assert_false(DayManagerScript.is_late_night(1439.9), "11:59 PM is not yet late night")
	assert_true(DayManagerScript.is_late_night(1440.0 + 60.0),
		"whole-day wraps resolve into the window (1 AM plus a full day)")


func test_night_lights_follow_the_sky() -> void:
	const NightLight := preload("res://scripts/night_light.gd")
	assert_eq(NightLight.night_factor(12 * 60.0), 0.0, "off at noon")
	assert_eq(NightLight.night_factor(23 * 60.0), 1.0, "full at night")
	assert_eq(NightLight.night_factor(3 * 60.0), 1.0, "still on before dawn")
	var dusk := NightLight.night_factor(18.75 * 60.0)
	assert_true(dusk > 0.0 and dusk < 1.0, "fading in at dusk (%.2f)" % dusk)
	var dawn := NightLight.night_factor(6.0 * 60.0)
	assert_true(dawn > 0.0 and dawn < 1.0, "fading out at dawn (%.2f)" % dawn)
	assert_eq(NightLight.night_factor(7 * 60.0), 0.0, "off after dawn")
