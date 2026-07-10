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


## The instant-interaction press-edge latch (2026-07-10 playtest bug-fix) — the pure rule behind
## "chest/bed/shipping box/NPC fire once per discrete press, never on held-key repeat, and a
## press a modal UI consumed to close itself never re-fires them." The live wiring (poll consume,
## modal tracking) needs a scene and is covered by tools/held_input_smoke.gd.
func test_instant_latch_rearms_on_release() -> void:
	assert_true(PlayerScript.instant_armed_next(false, false, false, false),
		"releasing the button re-arms a consumed latch")
	assert_true(PlayerScript.instant_armed_next(false, false, true, true),
		"release re-arms even while a modal is open (the NEXT press is a fresh edge)")


func test_instant_latch_holds_armed_state_while_pressed() -> void:
	assert_true(PlayerScript.instant_armed_next(true, true, false, false),
		"a fresh press keeps the latch armed until the poll consumes it")
	assert_false(PlayerScript.instant_armed_next(false, true, false, false),
		"holding after the poll consumed the edge stays disarmed — no per-frame re-fire")


func test_instant_latch_disarms_while_modal_open() -> void:
	assert_false(PlayerScript.instant_armed_next(true, true, true, false),
		"a press held while a modal is open belongs to that modal, not the world")


func test_instant_latch_disarms_on_frame_after_modal_closed() -> void:
	# The reported reopen bugs' exact shape: the press that closed a dialogue/store/shipping UI
	# is dispatched to _unhandled_input between physics frames, so the poll first sees it on the
	# frame AFTER the modal closed — modal_open is already false, but modal_was_open is not.
	assert_false(PlayerScript.instant_armed_next(true, true, false, true),
		"the press that closed a modal must not reopen the interaction one frame later")
