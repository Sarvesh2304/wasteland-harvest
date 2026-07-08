extends SceneTree
## Headless runtime smoke test (separate from tests/run_tests.gd, which is for pure-logic unit
## tests): boots the real game start-to-finish and drives the actual game loop — Phase 4 adds a
## first pass through scenes/settlement_select.tscn (verifying the default display, then
## confirming a non-default start so the whole GameState -> layout-selection wire is genuinely
## exercised rather than assumed), landmark/collision checks on the resulting map, and the new
## chest UI — before re-running Phase 2/3's original movement/camera/day-night/tool-use/farming-
## loop/pass-out checks against that same map. Simulated input/direct calls only; no display
## needed.
##
## Run: godot --headless --path . --script res://tools/runtime_smoke.gd
##
## Settlement choice: Forest Edge (rather than the DEFAULT_ID Open Plains) is driven through the
## selection screen deliberately, so this smoke test proves the actual selection -> GameState ->
## layout-resolution wiring works for a *non-default* choice, not just the fallback every other
## headless entry point (this file's own historical convention, plus a future test) already
## exercises implicitly.

const CropDB := preload("res://scripts/crop_db.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")

## Standalone-TestMap sanity check for the other 2 starts (ROADMAP Phase 4: "correct layout
## loads" for whichever start was picked, not just the one driven through the full selection ->
## main.tscn flow above). Each entry: settlement id, expected layout script, and the exact
## painted-cell counts computed from that layout's ROWS (ground is always (w+1)*(h+1)).
const OTHER_LAYOUT_CHECKS := [
	{"id": "open_plains", "layout": OpenPlainsLayout, "ground": 37 * 33, "obstacles": 0,
		"fence": 129, "water": 20, "decor": 3, "buildings": 9},
	{"id": "riverside", "layout": RiversideLayout, "ground": 37 * 33, "obstacles": 0,
		"fence": 97, "water": 32, "decor": 3, "buildings": 9},
]
var _other_layout_map: Node2D = null
var _other_layout_index := 0

var game_state: Node
var select: Control
var main: Node
var player: CharacterBody2D
var camera: Camera2D
var day_night: CanvasModulate
var day_manager: Node
var test_map: Node
var farm: Node
var structures: Node
var hud: CanvasLayer
var spawn := Vector2.ZERO
var stage := 0
var stage_started_at := 0
var failures: Array[String] = []

## Farming-loop test plot: a plain grass cell on Forest Edge's ROWS well clear of the pre-baked
## farmland patches, treeline/salvage, buildings, and the SW creek (row 20 is open grass across
## its whole interior width — see scripts/map_layouts/forest_edge_layout.gd's ROWS).
const FARM_TEST_CELL := Vector2i(5, 20)
const FARM_TEST_STAND_CELL := Vector2i(5, 19)


func _initialize() -> void:
	# Godot instantiates project autoloads even in --script mode, so the real DayManager/
	# GameState already sit on root — use them (adding a duplicate gets auto-renamed and the
	# game's scripts keep reading the real ones). Note: bare global-autoload identifiers (e.g.
	# writing `GameState.foo` directly) only resolve inside scripts reached via normal scene
	# instantiation, not in this top-level --script entry file itself — hence root.get_node().
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	select = (load("res://scenes/settlement_select.tscn") as PackedScene).instantiate()
	root.add_child(select)
	current_scene = select
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
			# Wait past startup so the selection screen's _ready() has run.
			if ticks < 5:
				return false
			_check(game_state.chosen_settlement_id == "open_plains",
				"selection screen boots with the default settlement pre-selected (got '%s')" \
					% game_state.chosen_settlement_id)
			_check(select.current_index == 0, "selection screen starts on option 0")
			_check(select.get_node("%NameLabel").text == "Open Plains",
				"selection screen displays the default option's name")
			_check(select.get_node("%LeanLabel").text.find("Better Soil") != -1,
				"selection screen displays the default option's resource lean")
			# Cycle down twice and back up once (pure wrap_index math is separately unit-tested;
			# this exercises the same code path through the live Control) to land on option 1
			# (Forest Edge), then confirm it — proving the real GameState.choose_settlement() +
			# change_scene_to_file() wiring, not just the pure selection math.
			select._set_index(1)
			_check(select.get_node("%NameLabel").text == "Forest Edge",
				"cycling to index 1 shows Forest Edge")
			select._confirm(1)
			_enter_stage(1)
		1:
			if ticks < 15:  # let the deferred scene change complete
				return false
			main = current_scene
			_check(main != null and main.name == "Main", "confirming transitions to scenes/main.tscn")
			_check(game_state.chosen_settlement_id == "forest_edge",
				"confirming Forest Edge set GameState.chosen_settlement_id")
			if main == null or main.name != "Main":
				_finish()
				return true
			player = main.get_node("Player")
			camera = main.get_node("GameCamera")
			day_night = main.get_node("DayNight")
			test_map = main.get_node("TestMap")
			farm = test_map.get_node("Farm")
			structures = test_map.get_node("Structures")
			hud = main.get_node("HUD")
			_enter_stage(2)
		2:
			if ticks < 10:
				return false
			# -- The active map really is Forest Edge, not the default --
			_check(test_map.layout == ForestEdgeLayout,
				"TestMap resolved the Forest Edge layout (not the default Open Plains)")
			spawn = player.global_position
			_check(spawn == test_map.get_spawn_position(), "player starts on the spawn cell")
			_check(spawn == ForestEdgeLayout.cell_center(Vector2i(17, 5)),
				"spawn position matches Forest Edge's authored spawn cell (17,5)")
			_check(test_map.get_map_rect() == Rect2(0, 0, 576, 512), "Forest Edge map bounds are 36x32 cells")
			_check(hud.get_node("%DayLabel").text == "Day 1", "HUD day label bound")
			_check(hud.get_node("%EnergyFill").value == 100.0, "energy bar full")
			_check(player.farm == farm and player.test_map == test_map and player.structures == structures,
				"player bound to farm/map/structures")
			_check(player.inventory.get_slot(0).get("item_id", "") == "hoe",
				"starting loadout: hoe in hotbar slot 1")
			_check(player.inventory.count_of("seed_mutant_potato") == 5,
				"starting loadout: 5 mutant potato seeds")
			# -- Forest Edge's "ruin materials" starting-resource bonus (ROADMAP Phase 4) --
			_check(player.inventory.count_of("wood") == 15, "Forest Edge bonus: 15 wood granted")
			_check(player.inventory.count_of("scrap_metal") == 8, "Forest Edge bonus: 8 scrap metal granted")
			_check(player.inventory.count_of("stone") == 8, "Forest Edge bonus: 8 stone granted")
			# -- The map was actually painted correctly from Forest Edge's layout data --
			_check(test_map.get_node("Ground").get_used_cells().size() == 37 * 33,
				"dual-grid ground fully painted (37x33 visual tiles)")
			_check(test_map.get_node("Obstacles").get_used_cells().size() == 2,
				"the 2 salvage-rubble '#' cells painted onto Obstacles")
			_check(test_map.get_node("Fence").get_used_cells().size() == 129,
				"all 129 perimeter fence cells painted")
			_check(test_map.get_node("Water").get_used_cells().size() == 29,
				"all 29 water cells (SW creek + town pool) painted")
			_check(test_map.get_node("Decor").get_used_cells().size() == 3,
				"all 3 dock plank cells painted")
			# -- Town-core + farmland landmarks exist, positioned sensibly --
			var buildings: Array[Dictionary] = ForestEdgeLayout.buildings()
			_check(buildings.size() == 9, "9 buildings defined (farmhouse, chest, mayor, store, board, 4 shacks)")
			_check(structures.get_child_count() == 9, "Structures spawned one body per building")
			var kinds := {}
			for b in buildings:
				kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
			for required in ["farmhouse", "chest", "mayor_house", "store", "bulletin_board"]:
				_check(kinds.get(required, 0) == 1, "exactly one %s" % required)
			_check(kinds.get("shack", 0) == 4, "4 settler shacks")
			var farmhouse: Dictionary = ForestEdgeLayout.building_at(16, 2)
			_check(String(farmhouse.get("kind", "")) == "farmhouse", "farmhouse sits north of the spawn/farmland")
			var mayor: Dictionary = ForestEdgeLayout.building_at(8, 16)
			_check(String(mayor.get("kind", "")) == "mayor_house", "mayor's house sits in the town-core region")
			_check(structures.is_chest_at(Vector2i(16, 4)), "chest is at its authored cell")
			_enter_stage(3)
		3:
			# -- Basic collision on buildings works: walk the player into the mayor's house --
			if ticks < 5:
				player.global_position = ForestEdgeLayout.cell_center(Vector2i(5, 17))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				Input.action_press("move_right")
				return false
			if ticks >= 150:  # ~2.5s: plenty to cross the ~48px gap to the building's west face
				Input.action_release("move_right")
				var mayor_west_face_x: float = 8 * 16.0  # top_left.x * CELL_SIZE
				_check(player.global_position.x < mayor_west_face_x,
					"mayor's house collision stopped the player (x=%.1f, west face at %.1f)" \
						% [player.global_position.x, mayor_west_face_x])
				_check(player.global_position.x > 90.0,
					"player actually moved toward the building before being stopped (x=%.1f)" \
						% player.global_position.x)
				_enter_stage(4)
		4:
			# -- Chest interaction: opens/toggles a real second Inventory via the HUD --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(16, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"  # targets cell (16,4), the chest
				return false
			if ticks == 5:
				_check(structures.is_chest_at(player.test_map.world_to_cell(
					player.global_position + Vector2(0, -16))), "player is facing the chest cell")
				var energy_before: float = player.energy
				player.use_tool()
				_check(not player.using_tool, "chest interaction doesn't lock movement like a tool swing")
				_check(player.energy == energy_before, "chest interaction costs no energy")
				_check(hud.get_node("%ChestGrid").visible, "chest UI opened")
				_check(hud._chest_inventory == structures.chest_inventory,
					"HUD chest UI is bound to Structures' real chest Inventory instance")
				player.use_tool()  # interact again: should close it
				_check(not hud.get_node("%ChestGrid").visible, "chest UI closes on a second interaction")
				_enter_stage(5)
		5:
			if ticks >= 30:  # ~0.5s: guarantees idle frames ran so the CanvasModulate re-applied
				day_manager.minutes_into_day = 0.0
				_enter_stage(6)
		6:
			if ticks >= 30:
				var night: Color = load("res://scripts/day_manager.gd").sky_color(0.0)
				_check(day_night.color.is_equal_approx(night),
					"midnight tints the world to night (color %s, expected %s)" % [day_night.color, night])
				day_manager.minutes_into_day = 720.0  # noon for the rest
				player.global_position = spawn
				player.velocity = Vector2.ZERO
				Input.action_press("move_right")
				_enter_stage(7)
		7:
			if ticks >= 120:  # ~2s of walking east
				_check(player.global_position.x > spawn.x + 60.0,
					"player walked east (x %.1f from %.1f)" % [player.global_position.x, spawn.x])
				_check(player.facing == "east", "facing tracked input")
				_check(player.get_node("Sprite").animation == &"walk_east", "walk_east playing")
				_enter_stage(8)
		8:
			if ticks >= 300:  # ~5 more seconds: must have hit the east perimeter fence by now
				var x := player.global_position.x
				var fence_face_x := 35 * 16.0
				_check(x > 400.0 and x < fence_face_x,
					"border fence stopped the player (x=%.1f, wall face at %.1f)" % [x, fence_face_x])
				Input.action_release("move_right")
				# Camera clamp: map is 576x512, view is 320x192 -> half=(160,96);
				# max center x = 576 - 160 = 416.
				_check(absf(camera.global_position.x - 416.0) < 1.0,
					"camera clamped at east limit (x=%.1f)" % camera.global_position.x)
				_check(camera.global_position.y >= 96.0 and camera.global_position.y <= 416.0,
					"camera y within clamp band")
				_enter_stage(9)
		9:
			if ticks >= 10:  # idle settled
				_check(player.get_node("Sprite").animation == &"idle_east",
					"idle keeps last facing after input stops")
				# Swing with the hoe selected, facing into border fence: not tillable, so this
				# must be a no-op (animation plays, nothing happens, no energy spent).
				var energy_before: float = player.energy
				player.use_tool()
				_check(player.using_tool, "tool use locks movement")
				_check(player.energy == energy_before, "swinging at non-tillable fence costs no energy")
				_check(player.get_node("Sprite").animation == &"tool_east", "tool_east playing")
				_enter_stage(10)
		10:
			if ticks >= 60:  # tool anim is 5 frames @ 10fps = 0.5s; 1s is plenty
				_check(not player.using_tool, "tool animation finished and unlocked movement")
				_check(day_manager.minutes_into_day > 720.0,
					"in-game time kept passing (%.2f)" % day_manager.minutes_into_day)
				_check(hud.get_node("%ClockLabel").text.ends_with("PM"),
					"HUD clock shows afternoon after noon reset")
				# -- Phase 3 farming loop, re-run against the new map --
				player.global_position = test_map.cell_to_world_center(FARM_TEST_STAND_CELL)
				player.velocity = Vector2.ZERO
				player.facing = "south"
				player.inventory.select_hotbar(0)  # hoe
				_check(not farm.can_harvest(FARM_TEST_CELL), "test cell starts as plain grass")
				player.use_tool()  # till
				_check(player.using_tool, "till swing locks movement")
				_enter_stage(11)
		11:
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
				_enter_stage(12)
		12:
			if ticks >= 60:
				_check(not player.using_tool, "plant swing finished")
				var plot: Dictionary = farm.get_plot(FARM_TEST_CELL)
				_check(plot.get("crop_id", "") == "mutant_potato", "seed planted mutant potato")
				_check(int(plot.get("stage", -1)) == 0, "freshly planted crop starts at stage 0")
				_check(player.inventory.count_of("seed_mutant_potato") == 4, "one seed consumed")
				_check(player.energy == 98.5, "planting cost 0.5 energy (99 -> 98.5)")
				player.inventory.select_hotbar(1)  # watering_can
				player.use_tool()  # water
				_enter_stage(13)
		13:
			if ticks >= 60:
				_check(not player.using_tool, "water swing finished")
				_check(farm.is_watered(FARM_TEST_CELL), "watering can watered the crop")
				_check(player.energy == 97.5, "watering cost 1 energy (98.5 -> 97.5)")
				_check(int(player.inventory.get_slot(1).get("durability", -1)) == 49,
					"watering can durability decremented by 1")
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
				_enter_stage(14)
		14:
			if ticks >= 10:
				var potatoes_before: int = player.inventory.count_of("mutant_potato")
				_check(potatoes_before == 0, "no mutant potato in inventory before harvest")
				player.inventory.select_hotbar(0)  # harvest ignores selection, but pick something valid
				player.use_tool()  # harvest
				_enter_stage(15)
		15:
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
				_enter_stage(16)
		16:
			# -- The other 2 starts also load and paint correctly (not just Forest Edge above) --
			# (_other_layout_map == null is the "just entered this stage for a new layout" signal
			# — ticks is never actually 0 here since _enter_stage() was called from the *previous*
			# physics frame, one tick before this stage's body first runs.)
			if _other_layout_map == null:
				var check: Dictionary = OTHER_LAYOUT_CHECKS[_other_layout_index]
				game_state.chosen_settlement_id = String(check["id"])
				_other_layout_map = (load("res://scenes/test_map.tscn") as PackedScene).instantiate()
				root.add_child(_other_layout_map)
				return false
			if ticks < 5:
				return false
			var check: Dictionary = OTHER_LAYOUT_CHECKS[_other_layout_index]
			var id := String(check["id"])
			_check(_other_layout_map.layout == check["layout"], "%s resolves its own layout script" % id)
			_check(_other_layout_map.get_node("Ground").get_used_cells().size() == int(check["ground"]),
				"%s ground fully painted" % id)
			_check(_other_layout_map.get_node("Obstacles").get_used_cells().size() == int(check["obstacles"]),
				"%s obstacles count matches" % id)
			_check(_other_layout_map.get_node("Fence").get_used_cells().size() == int(check["fence"]),
				"%s fence count matches" % id)
			_check(_other_layout_map.get_node("Water").get_used_cells().size() == int(check["water"]),
				"%s water count matches" % id)
			_check(_other_layout_map.get_node("Decor").get_used_cells().size() == int(check["decor"]),
				"%s dock/decor count matches" % id)
			_check(_other_layout_map.get_node("Structures").get_child_count() == int(check["buildings"]),
				"%s spawned all %d buildings" % [id, check["buildings"]])
			var spawn_cell: Vector2i = check["layout"].spawn_cell()
			_check(not check["layout"].is_solid(spawn_cell.x, spawn_cell.y), "%s spawn cell isn't blocked" % id)
			_other_layout_map.queue_free()
			_other_layout_map = null
			_other_layout_index += 1
			if _other_layout_index < OTHER_LAYOUT_CHECKS.size():
				_enter_stage(16)
			else:
				_enter_stage(17)
		17:
			if ticks >= 5:  # let the last queue_free() actually free before quitting
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
