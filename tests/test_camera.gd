extends "res://tests/test_case.gd"
## Camera clamping + shake-envelope math (Phase 2). Pure static functions on
## scripts/game_camera.gd — no live viewport needed. Numbers below use the real game
## dimensions: 320x192 viewport (project.godot) and the 512x320 px test map.

const GameCamera := preload("res://scripts/game_camera.gd")

const MAP := Rect2(0, 0, 512, 320)
const VIEW := Vector2(320, 192)


func test_target_inside_bounds_is_untouched() -> void:
	var center := Vector2(256, 160)
	assert_eq(GameCamera.clamp_center(center, MAP, VIEW), center,
		"map-center target needs no clamping")


func test_clamps_left_and_top() -> void:
	var clamped := GameCamera.clamp_center(Vector2(-500, -500), MAP, VIEW)
	assert_eq(clamped, Vector2(160, 96), "clamped to half the view size from the top-left edge")


func test_clamps_right_and_bottom() -> void:
	var clamped := GameCamera.clamp_center(Vector2(9999, 9999), MAP, VIEW)
	assert_eq(clamped, Vector2(512 - 160, 320 - 96), "clamped half a view short of bottom-right")


func test_clamps_mixed_axes() -> void:
	var clamped := GameCamera.clamp_center(Vector2(-50, 200), MAP, VIEW)
	assert_eq(clamped, Vector2(160, 200), "x clamps while in-bounds y passes through")


func test_view_edges_never_leave_map() -> void:
	# Property check across a sweep of wild targets: the visible rect implied by the clamped
	# center must always sit inside the map rect.
	for target in [Vector2(-1000, 50), Vector2(50, 5000), Vector2(300, 100),
			Vector2(511, 319), Vector2(0, 0), Vector2(100000, -100000)]:
		var c := GameCamera.clamp_center(target, MAP, VIEW)
		assert_true(c.x - VIEW.x / 2.0 >= MAP.position.x - 0.001, "left edge inside for %s" % target)
		assert_true(c.x + VIEW.x / 2.0 <= MAP.end.x + 0.001, "right edge inside for %s" % target)
		assert_true(c.y - VIEW.y / 2.0 >= MAP.position.y - 0.001, "top edge inside for %s" % target)
		assert_true(c.y + VIEW.y / 2.0 <= MAP.end.y + 0.001, "bottom edge inside for %s" % target)


func test_map_smaller_than_view_centers() -> void:
	var tiny := Rect2(0, 0, 160, 96)
	var clamped := GameCamera.clamp_center(Vector2(999, -999), tiny, VIEW)
	assert_eq(clamped, Vector2(80, 48), "a map smaller than the view centers instead of jittering")


func test_shake_envelope_decays_linearly() -> void:
	assert_eq(GameCamera.shake_offset(10.0, 1.0, 1.0), 10.0, "full intensity at start")
	assert_eq(GameCamera.shake_offset(10.0, 1.0, 0.5), 5.0, "half intensity halfway through")
	assert_eq(GameCamera.shake_offset(10.0, 1.0, 0.0), 0.0, "zero at the end")
	assert_eq(GameCamera.shake_offset(10.0, 0.0, 0.0), 0.0, "zero duration never divides by zero")
