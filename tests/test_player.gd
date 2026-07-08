extends "res://tests/test_case.gd"
## Player facing rule (Phase 2) — the pure static part of scripts/player.gd. Movement and
## animation playback need a live scene and are covered by the runtime smoke check instead.

const PlayerScript := preload("res://scripts/player.gd")


func test_cardinal_directions() -> void:
	assert_eq(PlayerScript.facing_from_input(Vector2.RIGHT, "south"), "east")
	assert_eq(PlayerScript.facing_from_input(Vector2.LEFT, "south"), "west")
	assert_eq(PlayerScript.facing_from_input(Vector2.UP, "south"), "north")
	assert_eq(PlayerScript.facing_from_input(Vector2.DOWN, "north"), "south")


func test_no_input_keeps_current_facing() -> void:
	for facing in ["south", "north", "east", "west"]:
		assert_eq(PlayerScript.facing_from_input(Vector2.ZERO, facing), facing,
			"idle keeps facing %s" % facing)


func test_diagonals_prefer_horizontal() -> void:
	assert_eq(PlayerScript.facing_from_input(Vector2(1, 1).normalized(), "south"), "east",
		"down-right diagonal faces east")
	assert_eq(PlayerScript.facing_from_input(Vector2(-1, -1).normalized(), "south"), "west",
		"up-left diagonal faces west")


func test_mostly_vertical_input_faces_vertically() -> void:
	assert_eq(PlayerScript.facing_from_input(Vector2(0.1, 0.9), "east"), "south")
	assert_eq(PlayerScript.facing_from_input(Vector2(-0.1, -0.9), "east"), "north")


## Phase 3 energy/pass-out math — the pure part of set_energy()/_pass_out(). Passing out itself
## (calling DayManager, refilling energy) needs a live scene and is covered by the runtime
## smoke check instead, same split as movement/animation above.
func test_energy_delta_clamps_to_range() -> void:
	var result := PlayerScript.apply_energy_delta(10.0, 100.0, -50.0)
	assert_eq(result["energy"], 0.0, "energy cannot go negative")
	result = PlayerScript.apply_energy_delta(95.0, 100.0, 50.0)
	assert_eq(result["energy"], 100.0, "energy cannot exceed max")


func test_energy_delta_flags_pass_out_on_crossing_zero() -> void:
	var result := PlayerScript.apply_energy_delta(3.0, 100.0, -4.0)
	assert_eq(result["energy"], 0.0)
	assert_true(result["passed_out"], "dropping from positive energy to <=0 triggers pass-out")


func test_energy_delta_does_not_repeat_pass_out_at_zero() -> void:
	var result := PlayerScript.apply_energy_delta(0.0, 100.0, -5.0)
	assert_eq(result["energy"], 0.0)
	assert_false(result["passed_out"], "already at zero — this delta didn't cause the crossing")


func test_energy_delta_no_pass_out_while_staying_positive() -> void:
	var result := PlayerScript.apply_energy_delta(10.0, 100.0, -4.0)
	assert_eq(result["energy"], 6.0)
	assert_false(result["passed_out"])
