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
