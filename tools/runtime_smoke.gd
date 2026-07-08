extends SceneTree
## Headless runtime smoke test (separate from tests/run_tests.gd, which is for pure-logic unit
## tests): boots the real main.tscn and drives the actual game loop — physics movement, wall
## collision, camera clamping, HUD binding, day/night tint, tool-use lock (Phase 2) — plus
## Phase 3's full farming loop end to end: till → plant → water → force a day advance → confirm
## growth → harvest → confirm the item lands in inventory, and a pass-out-at-zero-energy check.
## Simulated input/direct calls only; no display needed.
##
## Run: godot --headless --path . --script res://tools/runtime_smoke.gd

const CropDB := preload("res://scripts/crop_db.gd")

var main: Node
var player: CharacterBody2D
var camera: Camera2D
var day_night: CanvasModulate
var day_manager: Node
var test_map: Node
var farm: Node
var spawn := Vector2.ZERO
var stage := 0
var stage_started_at := 0
var failures: Array[String] = []

## Farming-loop test plot: a plain grass cell well clear of the pre-baked farm block, rubble,
## and the tree/ore resource nodes (see scripts/test_map_layout.gd's ROWS).
const FARM_TEST_CELL := Vector2i(10, 17)
const FARM_TEST_STAND_CELL := Vector2i(10, 16)


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
			test_map = main.get_node("TestMap")
			farm = test_map.get_node("Farm")
			spawn = player.global_position
			_check(spawn == test_map.get_spawn_position(),
				"player starts on the spawn cell (at %s, expected %s)" % [spawn, test_map.get_spawn_position()])
			_check(test_map.get_node("Ground").get_used_cells().size() == 33 * 21,
				"dual-grid ground fully painted")
			_check(test_map.get_node("Obstacles").get_used_cells().size() > 90,
				"rubble obstacles painted")
			_check(main.get_node("HUD").get_node("%DayLabel").text == "Day 1", "HUD day label bound")
			_check(main.get_node("HUD").get_node("%EnergyFill").value == 100.0, "energy bar full")
			_check(player.farm == farm and player.test_map == test_map, "player bound to farm/map")
			_check(player.inventory.get_slot(0).get("item_id", "") == "hoe",
				"starting loadout: hoe in hotbar slot 1")
			_check(player.inventory.count_of("seed_mutant_potato") == 5,
				"starting loadout: 5 mutant potato seeds")
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
				# Swing with the hoe selected, facing into border rubble: not tillable, so this
				# must be a no-op (animation plays, nothing happens, no energy spent) — proves
				# failed interactions don't silently cost the player anything.
				var energy_before: float = player.energy
				player.use_tool()
				_check(player.using_tool, "tool use locks movement")
				_check(player.energy == energy_before, "swinging at non-tillable rubble costs no energy")
				_check(player.get_node("Sprite").animation == &"tool_east", "tool_east playing")
				_enter_stage(5)
		5:
			if ticks >= 60:  # tool anim is 5 frames @ 10fps = 0.5s; 1s is plenty
				_check(not player.using_tool, "tool animation finished and unlocked movement")
				_check(day_manager.minutes_into_day > 720.0,
					"in-game time kept passing (%.2f)" % day_manager.minutes_into_day)
				_check(main.get_node("HUD").get_node("%ClockLabel").text.ends_with("PM"),
					"HUD clock shows afternoon after noon reset")
				# -- Phase 3 farming loop starts here --
				# Teleport to a clean grass cell (movement itself is already proven above) and
				# face south so the tile directly ahead is FARM_TEST_CELL.
				player.global_position = test_map.cell_to_world_center(FARM_TEST_STAND_CELL)
				player.velocity = Vector2.ZERO
				player.facing = "south"
				player.inventory.select_hotbar(0)  # hoe
				_check(not farm.can_harvest(FARM_TEST_CELL), "test cell starts as plain grass")
				player.use_tool()  # till
				_check(player.using_tool, "till swing locks movement")
				_enter_stage(6)
		6:
			if ticks >= 60:
				_check(not player.using_tool, "till swing finished")
				_check(test_map.is_tilled_at(FARM_TEST_CELL), "hoe tilled the target cell")
				_check(player.energy == 99.0, "till cost 1 energy (100 -> 99)")
				_check(int(player.inventory.get_slot(0).get("durability", -1)) == 49,
					"hoe durability decremented by 1")
				player.inventory.select_hotbar(5)  # seed_mutant_potato (see _give_starting_loadout)
				_check(player.inventory.get_slot(5).get("item_id", "") == "seed_mutant_potato",
					"seeds are in hotbar slot 6")
				player.use_tool()  # plant
				_enter_stage(7)
		7:
			if ticks >= 60:
				_check(not player.using_tool, "plant swing finished")
				var plot: Dictionary = farm.get_plot(FARM_TEST_CELL)
				_check(plot.get("crop_id", "") == "mutant_potato", "seed planted mutant potato")
				_check(int(plot.get("stage", -1)) == 0, "freshly planted crop starts at stage 0")
				_check(player.inventory.count_of("seed_mutant_potato") == 4, "one seed consumed")
				_check(player.energy == 98.5, "planting cost 0.5 energy (99 -> 98.5)")
				player.inventory.select_hotbar(1)  # watering_can
				player.use_tool()  # water
				_enter_stage(8)
		8:
			if ticks >= 60:
				_check(not player.using_tool, "water swing finished")
				_check(farm.is_watered(FARM_TEST_CELL), "watering can watered the crop")
				_check(player.energy == 97.5, "watering cost 1 energy (98.5 -> 97.5)")
				_check(int(player.inventory.get_slot(1).get("durability", -1)) == 49,
					"watering can durability decremented by 1")
				# Drive the remaining watered-day cycles directly through Farm/DayManager
				# (already proved the player -> Farm wiring above for till/plant/water; a smoke
				# test doesn't need to re-animate the same swing to prove it again 3 more times).
				var growth_stages := CropDB.growth_stages("mutant_potato")
				var days_advanced := 0
				while not farm.can_harvest(FARM_TEST_CELL) and days_advanced < growth_stages + 2:
					if farm.can_water(FARM_TEST_CELL):
						farm.water(FARM_TEST_CELL)
					day_manager.skip_to_next_morning()
					days_advanced += 1
				_check(farm.can_harvest(FARM_TEST_CELL),
					"crop reached its final stage after %d watered day advances (growth_stages=%d)" \
						% [days_advanced, growth_stages])
				_enter_stage(9)
		9:
			if ticks >= 10:
				var potatoes_before: int = player.inventory.count_of("mutant_potato")
				_check(potatoes_before == 0, "no mutant potato in inventory before harvest")
				player.inventory.select_hotbar(0)  # harvest ignores selection, but pick something valid
				player.use_tool()  # harvest
				_enter_stage(10)
		10:
			if ticks >= 60:
				_check(not player.using_tool, "harvest swing finished")
				_check(player.inventory.count_of("mutant_potato") == 1,
					"harvested mutant potato landed in inventory")
				_check(farm.get_plot(FARM_TEST_CELL).is_empty(),
					"plot cleared back to bare soil after harvest")
				_check(test_map.is_tilled_at(FARM_TEST_CELL),
					"cell stays tilled (replantable) after harvest, doesn't revert to grass")
				# -- Pass-out-at-zero-energy check --
				var day_before: int = day_manager.day
				player.set_energy(3.0)
				player.set_energy(-50.0)  # crosses from positive to <=0 -> should pass out
				_check(day_manager.day == day_before + 1,
					"energy hitting zero triggered a day skip (day %d -> %d)" % [day_before, day_manager.day])
				_check(day_manager.clock_text() == "6:00 AM", "woke up at 6:00 AM")
				_check(player.energy == player.max_energy, "waking up restores full energy")
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
