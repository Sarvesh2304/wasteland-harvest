extends SceneTree
## Headless runtime smoke test for Phase 2 (separate from tests/run_tests.gd, which is for
## pure-logic unit tests): boots the real main.tscn and drives the actual game loop —
## physics movement, wall collision, camera clamping, HUD binding, day/night tint, and the
## tool-use lock — using simulated input. No display needed; physics and node processing
## both run headless.
##
## Run: godot --headless --path . --script res://tools/runtime_smoke.gd

var main: Node
var player: CharacterBody2D
var camera: Camera2D
var day_night: CanvasModulate
var day_manager: Node
var spawn := Vector2.ZERO
var stage := 0
var stage_started_at := 0
var failures: Array[String] = []


func _initialize() -> void:
	# Godot instantiates project autoloads even in --script mode, so the real DayManager
	# already sits on root — use it (adding a duplicate gets auto-renamed and the game's
	# scripts keep reading the real one).
	day_manager = root.get_node("DayManager")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	camera = main.get_node("GameCamera")
	day_night = main.get_node("DayNight")
	# NOTE: node _ready callbacks have NOT run yet here — in --script mode they fire on the
	# first main-loop iteration, so all state inspection happens in the staged checks below.


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("stage %d: %s" % [stage, message])


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			# Wait well past startup: the first main-loop iteration can batch several physics
			# ticks (accumulated startup time), and _ready + idle processing must have run.
			if ticks < 10:
				return false
			# Scene wired: player on spawn, map painted, HUD bound.
			var map := main.get_node("TestMap")
			spawn = player.global_position
			_check(spawn == map.get_spawn_position(),
				"player starts on the spawn cell (at %s, expected %s)" % [spawn, map.get_spawn_position()])
			_check(map.get_node("Ground").get_used_cells().size() == 33 * 21,
				"dual-grid ground fully painted")
			_check(map.get_node("Obstacles").get_used_cells().size() > 90,
				"rubble obstacles painted")
			_check(main.get_node("HUD").get_node("%DayLabel").text == "Day 1", "HUD day label bound")
			_check(main.get_node("HUD").get_node("%EnergyFill").value == 100.0, "energy bar full")
			# Force midnight and let a frame tick the CanvasModulate.
			day_manager.minutes_into_day = 0.0
			_enter_stage(1)
		1:
			if ticks >= 30:  # ~0.5s: guarantees idle frames ran so the CanvasModulate re-applied
				var night: Color = load("res://scripts/day_manager.gd").sky_color(0.0)
				_check(day_night.color.is_equal_approx(night),
					"midnight tints the world to night (color %s, expected %s)" % [day_night.color, night])
				day_manager.minutes_into_day = 720.0  # noon for the rest
				Input.action_press("move_right")
				_enter_stage(2)
		2:
			if ticks >= 120:  # ~2s of walking east
				_check(player.global_position.x > spawn.x + 60.0,
					"player walked east (x %.1f from %.1f)" % [player.global_position.x, spawn.x])
				_check(player.facing == "east", "facing tracked input")
				_check(player.get_node("Sprite").animation == &"walk_east", "walk_east playing")
				_enter_stage(3)
		3:
			if ticks >= 300:  # ~5 more seconds: must have hit the east rubble border by now
				var x := player.global_position.x
				_check(x > 400.0 and x < 496.0,
					"border rubble stopped the player (x=%.1f, wall face at 496)" % x)
				Input.action_release("move_right")
				# Camera is clamped: max center x = 512 - 160 = 352 while the player is at ~489.
				_check(absf(camera.global_position.x - 352.0) < 1.0,
					"camera clamped at east limit (x=%.1f)" % camera.global_position.x)
				_check(camera.global_position.y >= 96.0 and camera.global_position.y <= 224.0,
					"camera y within clamp band")
				_enter_stage(4)
		4:
			if ticks >= 10:  # idle settled
				_check(player.get_node("Sprite").animation == &"idle_east",
					"idle keeps last facing after input stops")
				player.use_tool()
				_check(player.using_tool, "tool use locks movement")
				_check(player.energy == 98.0, "tool use spent stub energy")
				_check(player.get_node("Sprite").animation == &"tool_east", "tool_east playing")
				_enter_stage(5)
		5:
			if ticks >= 60:  # tool anim is 5 frames @ 10fps = 0.5s; 1s is plenty
				_check(not player.using_tool, "tool animation finished and unlocked movement")
				_check(day_manager.minutes_into_day > 720.0,
					"in-game time kept passing (%.2f)" % day_manager.minutes_into_day)
				_check(main.get_node("HUD").get_node("%ClockLabel").text.ends_with("PM"),
					"HUD clock shows afternoon after noon reset")
				_finish()
		_:
			pass
	return false


func _finish() -> void:
	if failures.is_empty():
		print("RUNTIME SMOKE: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			print("RUNTIME SMOKE FAIL: %s" % failure)
		quit(1)
