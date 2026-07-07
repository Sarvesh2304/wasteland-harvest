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
