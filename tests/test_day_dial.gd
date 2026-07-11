extends "res://tests/test_case.gd"
## Pure fill-fraction math for the HUD's day-progress dial (2026-07-11 HUD redesign session) —
## the static part of scripts/day_dial.gd. The live per-frame wiring (hud.gd calling
## set_fraction() from _on_time_changed, and _draw()'s actual arc rendering) needs a running
## scene/renderer and isn't exercised headlessly, same convention as test_hud.gd's chest
## walk-away check above.
##
## All cases below pass DAY_START_MINUTES (6:00 AM) explicitly, matching hud.gd's real call —
## the gameplay day runs 6 AM to 6 AM (DayManager), not midnight to midnight, even though
## minutes_into_day itself is plain wall-clock minutes since midnight.

const DayDialScript := preload("res://scripts/day_dial.gd")

const MINUTES_PER_DAY := 24 * 60
const DAY_START_MINUTES := 6 * 60  # matches DayManager.DAY_START_MINUTES


func test_day_start_is_zero_progress() -> void:
	assert_eq(DayDialScript.day_progress_fraction(
			float(DAY_START_MINUTES), MINUTES_PER_DAY, DAY_START_MINUTES), 0.0,
		"the moment a day begins (6 AM), the dial reads empty")


func test_midnight_is_three_quarters_through_the_gameplay_day() -> void:
	# Midnight (minutes_into_day = 0) is 18 hours after the 6 AM day-start, i.e. 18/24 = 0.75
	# through the 6 AM-to-6 AM gameplay day — not literal midnight-relative time.
	var fraction := DayDialScript.day_progress_fraction(0.0, MINUTES_PER_DAY, DAY_START_MINUTES)
	assert_true(is_equal_approx(fraction, 0.75), "midnight reads as 75%% through the day")


func test_progress_increases_monotonically_across_the_day() -> void:
	var morning := DayDialScript.day_progress_fraction(
		float(DAY_START_MINUTES), MINUTES_PER_DAY, DAY_START_MINUTES)  # 6:00 AM
	var noon := DayDialScript.day_progress_fraction(720.0, MINUTES_PER_DAY, DAY_START_MINUTES)
	var afternoon := DayDialScript.day_progress_fraction(
		900.0, MINUTES_PER_DAY, DAY_START_MINUTES)  # 3:00 PM
	assert_true(morning < noon, "progress at noon exceeds progress at the day's start")
	assert_true(noon < afternoon, "progress at 3 PM exceeds progress at noon")


func test_progress_resets_to_zero_on_a_new_day() -> void:
	# Just before 6 AM (a hair under DAY_START_MINUTES) should read almost-full; exactly at
	# DAY_START_MINUTES again (whether reached by a natural day rollover carrying minutes_into_day
	# past 1440 back around to 360, or by skip_to_next_morning() explicitly landing there after a
	# sleep/pass-out) must read back to exactly 0 — proving the dial "resets on the next day" per
	# the playtest ask.
	var almost_full := DayDialScript.day_progress_fraction(
		float(DAY_START_MINUTES) - 0.01, MINUTES_PER_DAY, DAY_START_MINUTES)
	var reset := DayDialScript.day_progress_fraction(
		float(DAY_START_MINUTES), MINUTES_PER_DAY, DAY_START_MINUTES)
	assert_true(almost_full > 0.999, "the instant before a new day, the dial reads nearly full")
	assert_eq(reset, 0.0, "the instant a new day starts, the dial reads fully reset")


func test_fraction_never_exceeds_valid_range() -> void:
	for minute in [0.0, 1.0, 359.0, 360.0, 719.0, 720.0, 1439.0, 1440.0, 2880.0, 100000.0]:
		var fraction := DayDialScript.day_progress_fraction(
			minute, MINUTES_PER_DAY, DAY_START_MINUTES)
		assert_true(fraction >= 0.0 and fraction < 1.0,
			"fraction for minute %s stays in [0, 1)" % minute)


func test_zero_length_day_is_handled_safely() -> void:
	assert_eq(DayDialScript.day_progress_fraction(500.0, 0.0, DAY_START_MINUTES), 0.0,
		"a degenerate zero-length day never divides by zero")


func test_default_day_start_offset_is_zero() -> void:
	# day_start_minutes defaults to 0.0 when omitted, so existing/simple callers that only care
	# about literal midnight-relative time keep working unchanged.
	assert_eq(DayDialScript.day_progress_fraction(360.0, MINUTES_PER_DAY), 0.25,
		"without an explicit day-start offset, fraction is plain minutes_into_day / period")
