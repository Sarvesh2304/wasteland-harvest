extends "res://tests/test_case.gd"
## The chest walk-away auto-close's pure distance rule (2026-07-10 playtest UX gap) — the static
## part of scripts/hud.gd. The live wiring (tracking the interacted cell through toggle_chest_ui,
## the per-frame _process check against the real player) needs a scene and is covered by
## tools/held_input_smoke.gd.

const HudScript := preload("res://scripts/hud.gd")

## The reference chest cell for every case below; its world center is (40, 72) at the 16px grid.
const CHEST := Vector2i(2, 4)
const CHEST_CENTER := Vector2(40, 72)


func test_interacting_position_is_in_range() -> void:
	# Standing on the cell directly south (the use_tool interacting position): 16px away.
	assert_false(HudScript.chest_out_of_range(CHEST_CENTER + Vector2(0, 16), CHEST),
		"the position the chest was opened from is comfortably in range")


func test_shuffling_around_the_chest_stays_in_range() -> void:
	# Worst nearby drift: a diagonal-adjacent cell center, ~22.6px away — sorting-adjacent
	# movement must never slam the UI shut.
	assert_false(HudScript.chest_out_of_range(CHEST_CENTER + Vector2(16, 16), CHEST),
		"diagonal-adjacent shuffling stays open")
	assert_false(HudScript.chest_out_of_range(CHEST_CENTER + Vector2(-32, 16), CHEST),
		"two tiles off to the side is still within the 3-tile threshold")


func test_threshold_boundary_is_exclusive() -> void:
	assert_false(HudScript.chest_out_of_range(
		CHEST_CENTER + Vector2(HudScript.CHEST_CLOSE_DISTANCE, 0), CHEST),
		"exactly at the threshold is still in range (strictly-beyond closes)")
	assert_true(HudScript.chest_out_of_range(
		CHEST_CENTER + Vector2(HudScript.CHEST_CLOSE_DISTANCE + 0.5, 0), CHEST),
		"a hair beyond the threshold is out of range")


func test_walking_away_is_out_of_range() -> void:
	assert_true(HudScript.chest_out_of_range(CHEST_CENTER + Vector2(0, 64), CHEST),
		"four tiles away closes the chest")
	assert_true(HudScript.chest_out_of_range(CHEST_CENTER + Vector2(48, 48), CHEST),
		"a diagonal walk-away closes it too (euclidean, not per-axis)")


func test_custom_max_distance_is_respected() -> void:
	assert_true(HudScript.chest_out_of_range(CHEST_CENTER + Vector2(20, 0), CHEST, 16.0),
		"an explicit tighter threshold overrides the default")


## -- 2026-07-11 forced-sleep session: the sleepy cue's pure pulse curve --

func test_sleepy_pulse_stays_visible_and_in_alpha_range() -> void:
	var lowest := 1.0
	var highest := 0.0
	for i in 100:  # sweep well past one full ~1.25s cycle
		var alpha := HudScript.sleepy_pulse_alpha(i * 0.02)
		lowest = minf(lowest, alpha)
		highest = maxf(highest, alpha)
		assert_true(alpha >= 0.0 and alpha <= 1.0, "alpha stays a valid modulate value")
	assert_true(lowest >= 0.0999, "the trough never fully hides the cue (min ~0.1)")
	assert_true(highest > 0.95, "the peak reaches full visibility")
	assert_true(highest - lowest > 0.5, "the pulse actually breathes rather than sitting still")


## -- 2026-08-09 HUD polish: the sleepy cue's one-shot midnight-edge rule --
##
## The bug this replaces: hud.gd mirrored DayManager.is_late_night() into the label's visibility
## every tick, so the cue sat on screen for the entire midnight-to-6-AM window. The new rule is
## an EDGE, deliberately shaped like player.gd's own survived_night() (its 6 AM counterpart) —
## see tests/test_player.gd's night-rule cases for the sibling coverage.

func test_the_midnight_wrap_fires_the_cue_exactly_once() -> void:
	assert_true(HudScript.crossed_into_night(1439.5, 0.5),
		"the tick that wraps 11:59 PM -> 12:00 AM raises the cue")
	assert_false(HudScript.crossed_into_night(0.5, 1.5),
		"the very next tick does NOT re-raise it — this is the whole point of the fix")
	assert_false(HudScript.crossed_into_night(90.0, 91.0),
		"a 1:30 AM tick deep inside the window is not an edge")
	assert_false(HudScript.crossed_into_night(359.0, 359.5),
		"nor is the last minute before 6 AM")


func test_daytime_and_evening_ticks_never_fire_the_cue() -> void:
	assert_false(HudScript.crossed_into_night(720.0, 721.0), "noon is not a midnight crossing")
	assert_false(HudScript.crossed_into_night(1200.0, 1201.0), "8 PM is not either")
	assert_false(HudScript.crossed_into_night(1438.0, 1439.0),
		"11:58 PM -> 11:59 PM stays on the near side of midnight")


func test_the_six_am_wake_edge_is_not_a_night_crossing() -> void:
	# The mirror-image edge player.gd::survived_night() owns: leaving the window, not entering
	# it. Both are forward-moving ticks; only the wrap belongs to this cue.
	assert_false(HudScript.crossed_into_night(359.5, 360.5),
		"crossing 6 AM ends the night — it must never raise the cue")


func test_a_tick_that_jumps_the_whole_window_is_rejected() -> void:
	# Unreachable from a frame delta (>6 game-hours in one emission) but reachable from test
	# tooling: the clock wrapped, yet the player is already past 6 AM, so "getting sleepy" would
	# be a lie. The is_late_night() conjunct in the rule exists for exactly this case.
	assert_false(HudScript.crossed_into_night(1400.0, 400.0),
		"a wrap that lands clean past 6 AM is not a sleepy-window entry")
	assert_true(HudScript.crossed_into_night(1400.0, 359.0),
		"...but a wrap landing inside the window still counts, however large the jump")


## -- 2026-08-09 HUD polish: cancelling the day/night wash on the world-space cue --

const DayManagerScript := preload("res://scripts/day_manager.gd")


func test_compensation_restores_the_authored_colour_at_midnight() -> void:
	# The real case: the cue only ever shows just past midnight, where the sky sits flat at
	# DayManager's deep-night keyframe. Authored colour * sky * compensation must come back out
	# as the authored colour — that's the whole contract.
	var sky := DayManagerScript.sky_color(0.0)
	var comp := HudScript.tint_compensation(sky)
	var authored := Color(0.694118, 0.72549, 0.909804)  # the SleepyLabel's font_color
	var seen := Color(authored.r * sky.r * comp.r, authored.g * sky.g * comp.g,
		authored.b * sky.b * comp.b)
	assert_true(seen.is_equal_approx(authored),
		"the cue renders in its authored colour under the night wash (got %s)" % seen)
	assert_true(comp.r > 1.0 and comp.g > 1.0 and comp.b > 1.0,
		"night genuinely needs a gain above 1 (got %s) — this isn't a no-op" % comp)


func test_compensation_is_a_no_op_under_an_untinted_sky() -> void:
	# Noon is unmodulated white; nothing to cancel.
	var comp := HudScript.tint_compensation(Color.WHITE)
	assert_true(comp.is_equal_approx(Color(1, 1, 1)),
		"an untinted sky needs no gain (got %s)" % comp)


func test_compensation_is_capped_against_a_black_sky() -> void:
	# Not reachable from today's keyframes — a guard so a future gradient edit can't produce an
	# absurd multiplier (or a division by zero).
	var comp := HudScript.tint_compensation(Color(0.0, 0.0, 0.0), 8.0)
	assert_true(comp.r == 8.0 and comp.g == 8.0 and comp.b == 8.0,
		"a black sky clamps at max_gain instead of exploding (got %s)" % comp)


## -- HUD v2 (2026-10-07) --

func test_prompt_text_lists_both_buttons() -> void:
	assert_eq(HudScript.prompt_text({"use": "Chop", "interact": "Pick up"}, "Space", "E"),
		"Space Chop   E Pick up")
	assert_eq(HudScript.prompt_text({"use": "Till", "interact": ""}, "Space", "E"), "Space Till")
	assert_eq(HudScript.prompt_text({"use": "Talk", "interact": "Talk"}, "Space", "E"), "E Talk",
		"one verb on both buttons shows once, on Interact")
	assert_eq(HudScript.prompt_text({"use": "", "interact": ""}, "Space", "E"), "")


func test_upgraded_tools_use_their_own_icon() -> void:
	assert_eq(HudScript.slot_icon_path("hoe", 3, "res://art/items/hoe.png"), "res://art/items/hoe_t3.png")
	assert_eq(HudScript.slot_icon_path("hoe", 1, "res://art/items/hoe.png"), "res://art/items/hoe.png")
	assert_eq(HudScript.slot_icon_path("wood", 3, "res://art/items/wood.png"), "res://art/items/wood.png",
		"only tools have tiers")


func test_watering_can_capacity_by_tier() -> void:
	const ItemDBScript := preload("res://scripts/item_db.gd")
	assert_eq(ItemDBScript.can_capacity(1), 40)
	assert_eq(ItemDBScript.can_capacity(4), 100)
	assert_eq(ItemDBScript.can_capacity(9), 100, "clamped")
