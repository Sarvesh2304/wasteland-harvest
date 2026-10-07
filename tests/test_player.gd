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


## -- 2026-07-11 forced-sleep night rules — the pure parts of _on_time_changed. The live wiring
##    (time_changed signal, _pass_out with save, coffee via the real consume path) needs a scene
##    and is covered by tools/sleep_smoke.gd + the soak test's stay-up-all-night stage. --

func test_late_night_drain_outside_window_is_free() -> void:
	assert_eq(PlayerScript.late_night_drain(720.0, 721.0, 0.15), 0.0,
		"a daytime tick drains nothing")
	assert_eq(PlayerScript.late_night_drain(1400.0, 1439.9, 0.15), 0.0,
		"late evening up to (not across) midnight drains nothing")
	assert_eq(PlayerScript.late_night_drain(360.0, 400.0, 0.15), 0.0,
		"the tick leaving 6 AM drains nothing (window is exclusive at DAY_START)")


func test_late_night_drain_is_proportional_inside_window() -> void:
	assert_true(absf(PlayerScript.late_night_drain(30.0, 31.0, 0.15) - 0.15) < 0.0001,
		"one game-minute past midnight costs exactly the per-minute rate")
	assert_true(absf(PlayerScript.late_night_drain(0.0, 120.0, 0.15) - 18.0) < 0.0001,
		"the full midnight-to-2-AM stretch costs 18 energy at the shipped 0.15 rate")


func test_late_night_drain_clips_partial_overlaps() -> void:
	# The tick that wraps midnight: only the post-midnight sliver is in the window.
	assert_true(absf(PlayerScript.late_night_drain(1439.5, 0.5, 0.15) - 0.5 * 0.15) < 0.0001,
		"a midnight-wrapping tick charges only its post-midnight portion")
	# A (coffee-extended) tick crossing 6 AM: only the pre-6-AM portion is in the window.
	assert_true(absf(PlayerScript.late_night_drain(350.0, 370.0, 0.15) - 10.0 * 0.15) < 0.0001,
		"a tick crossing 6 AM charges only its late-night portion")


func test_should_force_passout_is_the_2am_band_check() -> void:
	assert_false(PlayerScript.should_force_passout(119.9, false),
		"1:59 AM is sleepy but not yet the cutoff")
	assert_true(PlayerScript.should_force_passout(120.0, false),
		"2:00 AM exactly forces the pass-out")
	assert_true(PlayerScript.should_force_passout(200.0, false),
		"anywhere inside [2 AM, 6 AM) forces it — a state check, not a crossing edge")
	assert_false(PlayerScript.should_force_passout(360.0, false),
		"6:00 AM exactly is morning (where every sleep transition lands) — never a trigger")
	assert_false(PlayerScript.should_force_passout(720.0, false), "daytime never triggers")


func test_stay_awake_suppresses_the_forced_passout() -> void:
	assert_false(PlayerScript.should_force_passout(120.0, true),
		"a live coffee charge lets the player push past 2 AM")
	assert_false(PlayerScript.should_force_passout(300.0, true),
		"...all the way through the night")


func test_survived_night_crossing_spends_the_charge() -> void:
	assert_true(PlayerScript.survived_night(359.0, 361.0),
		"crossing 6 AM awake ends the protected night")
	assert_false(PlayerScript.survived_night(361.0, 362.0),
		"a morning tick after the crossing is not a second crossing")
	assert_false(PlayerScript.survived_night(1439.0, 0.5),
		"wrapping midnight is entering the night, not surviving it")
	assert_false(PlayerScript.survived_night(100.0, 119.0),
		"still inside the night — charge stays live")


func test_instant_latch_disarms_on_frame_after_modal_closed() -> void:
	# The reported reopen bugs' exact shape: the press that closed a dialogue/store/shipping UI
	# is dispatched to _unhandled_input between physics frames, so the poll first sees it on the
	# frame AFTER the modal closed — modal_open is already false, but modal_was_open is not.
	assert_false(PlayerScript.instant_armed_next(true, true, false, true),
		"the press that closed a modal must not reopen the interaction one frame later")


## -- 2026-10-07 aiming: keyboard faces the next cell; the mouse picks any cell within reach --

func test_keyboard_targets_the_faced_cell() -> void:
	var at := Vector2i(10, 10)
	assert_eq(PlayerScript.target_cell_for(at, "north", Vector2i.ZERO, false), Vector2i(10, 9))
	assert_eq(PlayerScript.target_cell_for(at, "east", Vector2i.ZERO, false), Vector2i(11, 10))
	assert_eq(PlayerScript.target_cell_for(at, "bogus", Vector2i.ZERO, false), Vector2i(10, 11),
		"unknown facing falls back to south")


func test_mouse_targets_within_reach() -> void:
	var at := Vector2i(10, 10)
	assert_eq(PlayerScript.target_cell_for(at, "south", Vector2i(11, 9), true), Vector2i(11, 9),
		"diagonal neighbours are in reach")
	assert_eq(PlayerScript.target_cell_for(at, "south", Vector2i(15, 10), true), Vector2i(11, 10),
		"far clicks clamp to the adjacent cell in that direction")
	assert_eq(PlayerScript.target_cell_for(at, "south", Vector2i(4, 2), true), Vector2i(9, 9))
	assert_eq(PlayerScript.target_cell_for(at, "west", at, true), Vector2i(9, 10),
		"pointing at yourself uses your facing")


func test_facing_toward_a_target() -> void:
	assert_eq(PlayerScript.facing_toward(Vector2i(5, 5), Vector2i(6, 5), "south"), "east")
	assert_eq(PlayerScript.facing_toward(Vector2i(5, 5), Vector2i(5, 4), "south"), "north")
	assert_eq(PlayerScript.facing_toward(Vector2i(5, 5), Vector2i(4, 4), "south"), "west",
		"horizontal wins diagonal ties")
	assert_eq(PlayerScript.facing_toward(Vector2i(5, 5), Vector2i(5, 5), "north"), "north",
		"no direction keeps the current facing")
