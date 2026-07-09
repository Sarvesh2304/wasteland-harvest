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
## Phase 4 Stage 2 (stages 16-19): drives the new building-placement mode end-to-end — enter
## build mode via the real input handler, cycle the catalog, place a Storage Shed blueprint from
## the Forest Edge starting materials, verify resources/energy were spent and the site blocks
## tilling/re-placement, advance a day, confirm the shed became a real collidable building AND a
## working second storage chest; then gather wood by chopping a tree and build a Shelter Tent the
## same way, proving the "gather -> afford -> place -> wait a day" loop from zero spare resources.
##
## Phase 4 Stage 3 (stages 20-23): the full auto-save round trip — the literal phase milestone
## ("Player can quit and reload mid-playthrough with all state restored"). After all the play
## above, the player sleeps in the farmhouse bed via the real use_tool interaction (day advances,
## energy refills, "WORLD SAVED" notice appears, save file written), then a fresh boot is
## simulated: the whole main scene is torn down, GameState/DayManager are deliberately reset to
## wrong values, and scenes/settlement_select.tscn is instantiated again exactly as a real launch
## would — its Stage 3 resume path must skip the picker, reload the save, and restore crops,
## tilled soil, chopped-resource removals, inventory (incl. tool durability + hotbar selection),
## player position/facing/energy, both player-built structures with their storage contents, the
## chest contents, the day/clock, and the chosen settlement. Uses a test-only save filename
## (game_state.save_path) deleted both before and after, so repeated runs never inherit stale
## state — a hard requirement, not hygiene theater.
##
## Run: godot --headless --path . --script res://tools/runtime_smoke.gd
##
## Settlement choice: Forest Edge (rather than the DEFAULT_ID Open Plains) is driven through the
## selection screen deliberately, so this smoke test proves the actual selection -> GameState ->
## layout-resolution wiring works for a *non-default* choice, not just the fallback every other
## headless entry point (this file's own historical convention, plus a future test) already
## exercises implicitly.
##
## Phase 5 Stage 1 (stages 50-61, spliced in between Phase 3's pass-out check and Phase 4 Stage
## 2's building placement — chosen because NPC dialogue is energy-free like the chest/bed, so it
## can't perturb the exact energy-ledger arithmetic stages 16-19 already assert against a known
## starting value): approaches Mayor Harlan through the real facing+use_tool interaction path,
## verifies the dialogue box opens bound to the right NPC at no energy cost, that a held movement
## key is genuinely ignored while talking, that the typewriter reveal is truly character-by-
## character (a partial string spotted mid-reveal) before instantly-revealing, walks both
## branches of Harlan's "basic branching" choice via the real move_down + use_tool input path
## (proving they lead to distinct follow-up lines and that a fresh visit resets the highlighted
## option), repeats the same real interaction against Marta (stages 54-55) and Scout Kael, confirms
## the player can still walk normally afterward, then lets ~10s of simulated time pass and checks
## every NPC actually stepped at least once while never leaving its authored wander zone or its
## cell ever reading as blocked terrain.
##
## Phase 5 Stage 2 (stages 90-95, spliced in between Marta's dialogue (stage 55) and Scout Kael
## (stage 57) — Marta's "Let's see what you've got" choice is what opens the store, so this is the
## natural point in the flow to drive it): confirms choosing that option actually opened
## scripts/store_ui.gd (not just closed the dialogue), grants the player enough Credits to test an
## affordable purchase (Credits aren't earnable yet — Stage 3's shipping box is next session — so
## this is the same "seed distinctive state to exercise" convention stage 20 already uses for
## energy/inventory), buys a seed (row 0) via the real move/use_tool input path and confirms the
## exact Credits deducted and the item landed in inventory via Inventory.add_item, cycles down to
## the pickaxe row and buys a replacement tool (confirming a FRESH full-durability instance
## appears, not a stacked count), then drops the balance too low to afford anything and confirms
## an attempted purchase is refused with zero deduction and zero items granted, then leaves via
## the trailing "Leave" row and confirms the player can move/act normally immediately after — the
## same "shouldn't leave the player stuck" standard Stage 1 verified for dialogue.

const CropDB := preload("res://scripts/crop_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")
const NpcGrid := preload("res://scripts/npc_grid.gd")

## Standalone-TestMap sanity check for the other 2 starts (ROADMAP Phase 4: "correct layout
## loads" for whichever start was picked, not just the one driven through the full selection ->
## main.tscn flow above). Each entry: settlement id, expected layout script, and the exact
## painted-cell counts computed from that layout's ROWS (ground is always (w+1)*(h+1)).
const OTHER_LAYOUT_CHECKS := [
	{"id": "open_plains", "layout": OpenPlainsLayout, "ground": 37 * 33, "obstacles": 0,
		"fence": 129, "water": 20, "decor": 3, "buildings": 10},
	{"id": "riverside", "layout": RiversideLayout, "ground": 37 * 33, "obstacles": 0,
		"fence": 97, "water": 32, "decor": 3, "buildings": 10},
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
var builder: Node2D
var hud: CanvasLayer
## Phase 5 Stage 1: NPC roster + dialogue box, fetched once in stage 2 alongside structures/hud.
var npcs: Node
var dialogue_ui: Node
## Phase 5 Stage 2: Marta's store, fetched once in stage 2 alongside dialogue_ui above.
var store_ui: Node
## Wander-check snapshot (stage 60): each NPC's cell recorded once, compared after simulated time.
var _wander_start_cells: Dictionary = {}
## Position snapshot for stage 95's post-store movement check (see that stage).
var _store_check_start_pos := Vector2.ZERO
var spawn := Vector2.ZERO
var stage := 0
var stage_started_at := 0
var failures: Array[String] = []

## Snapshot taken at the moment of the stage-20 bed save, compared against the reloaded world
## in stage 23.
var saved_day := 0
var saved_position := Vector2.ZERO

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
	# Stage 3 test hygiene (hard requirement, see class doc): point the save system at a
	# test-only filename and clear any stale copy a previous crashed run may have left, BEFORE
	# the selection screen's _ready() runs its has_save() resume check — otherwise this run
	# could inherit another run's world (or worse, a real playthrough's save at the default
	# path could hijack the picker this test drives).
	game_state.save_path = "user://runtime_smoke_save.json"
	game_state.delete_save()
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
			_check(not game_state.has_save(),
				"no save exists at the test path, so the picker (not the resume path) showed")
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
			npcs = test_map.get_node("Npcs")
			dialogue_ui = main.get_node("DialogueUI")
			store_ui = main.get_node("StoreUI")
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
			_check(buildings.size() == 10,
				"10 buildings defined (farmhouse, chest, bed, mayor, store, board, 4 shacks)")
			_check(structures.get_child_count() == 10, "Structures spawned one body per building")
			var kinds := {}
			for b in buildings:
				kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
			for required in ["farmhouse", "chest", "bed", "mayor_house", "store", "bulletin_board"]:
				_check(kinds.get(required, 0) == 1, "exactly one %s" % required)
			_check(kinds.get("shack", 0) == 4, "4 settler shacks")
			var farmhouse: Dictionary = ForestEdgeLayout.building_at(16, 2)
			_check(String(farmhouse.get("kind", "")) == "farmhouse", "farmhouse sits north of the spawn/farmland")
			var mayor: Dictionary = ForestEdgeLayout.building_at(8, 16)
			_check(String(mayor.get("kind", "")) == "mayor_house", "mayor's house sits in the town-core region")
			_check(structures.is_chest_at(Vector2i(16, 4)), "chest is at its authored cell")
			# -- Phase 5 Stage 1: the 3 town-core NPCs spawned at their authored home cells --
			_check(npcs.npcs().size() == 3, "3 NPCs spawned")
			for entry in ForestEdgeLayout.npcs():
				var npc: Node = _npc_by_id(String(entry["id"]))
				_check(npc != null, "npc '%s' exists" % entry["id"])
				if npc != null:
					_check(test_map.world_to_cell(npc.global_position) == entry["home"],
						"npc '%s' spawned at its authored home cell %s" % [entry["id"], entry["home"]])
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
				_enter_stage(50)
		50:
			# -- Phase 5 Stage 1: approach Mayor Harlan and open the dialogue box (see class doc's
			#    NPC section). Stands one cell south of wherever Harlan's actual live cell is
			#    (rather than his authored home) so this check is robust even if he's already
			#    taken a wander step by the time this stage runs.
			if ticks < 5:
				var npc: Node = _npc_by_id("mayor_harlan")
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.cell_to_world_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				var npc: Node = _npc_by_id("mayor_harlan")
				_check(not dialogue_ui.active, "dialogue box starts closed")
				var energy_before: float = player.energy
				player.use_tool()  # the real facing-based interaction path (player.gd's dispatch)
				_check(dialogue_ui.active, "interacting with Harlan opened the dialogue box")
				_check(dialogue_ui.npc == npc, "dialogue box is bound to the correct NPC")
				_check(bool(npc.talking), "the NPC freezes while talking")
				_check(player.energy == energy_before, "NPC dialogue costs no energy (like chest/bed)")
				_check(not player.using_tool, "opening dialogue doesn't lock a tool-swing animation")
				_check(dialogue_ui.get_node("%NameLabel").text == "Mayor Harlan",
					"name plate shows the NPC's display name")
				_check(dialogue_ui.get_node("%Box").visible, "dialogue box is visible")
				_enter_stage(51)
		51:
			# -- The player is genuinely frozen while talking (held movement input is ignored) --
			if ticks == 0:
				Input.action_press("move_right")
				return false
			if ticks < 6:
				return false
			if ticks == 6:
				_check(player.velocity == Vector2.ZERO,
					"player stays frozen mid-dialogue despite a held movement key")
				Input.action_release("move_right")
				# -- Character-by-character reveal: some, but not all, of the line is visible --
				var body_label: Label = dialogue_ui.get_node("%BodyLabel")
				var full_len: int = dialogue_ui._full_text.length()
				_check(body_label.text.length() > 0 and body_label.text.length() < full_len,
					"typewriter shows a partial line (%d/%d chars) before it finishes" \
						% [body_label.text.length(), full_len])
				_enter_stage(52)
		52:
			# -- Drive the real conversation through dialogue_ui's actual _unhandled_input path:
			#    reveal, advance two linear beats, reach the branch, pick "just looking" (index 1,
			#    exercising move_down + the SECOND choice), read its distinct follow-up, close. --
			if ticks >= 2:
				_drive_dialogue_action("use_tool")  # instantly reveal "greet"
				_check(dialogue_ui._is_fully_revealed(), "space instantly reveals the rest of a line")
				_drive_dialogue_action("use_tool")  # advance greet -> founding
				_check(dialogue_ui._node_id == "founding", "advanced past the greeting")
				_drive_dialogue_action("use_tool")  # reveal founding
				_drive_dialogue_action("use_tool")  # advance founding -> offer (the branch point)
				_check(dialogue_ui._node_id == "offer", "reached the branch point")
				_drive_dialogue_action("use_tool")  # reveal the branch prompt
				_check(dialogue_ui.get_node("%ChoicesBox").visible,
					"choice options appear once the branch prompt finishes revealing")
				_check(dialogue_ui._choice_index == 0, "first option highlighted by default")
				_drive_dialogue_action("move_down")
				_check(dialogue_ui._choice_index == 1, "move_down highlights the second option")
				_drive_dialogue_action("use_tool")  # confirm choice 1 -> offer_no
				_check(dialogue_ui._node_id == "offer_no",
					"confirming the highlighted (2nd) option followed ITS branch, not the 1st")
				var offer_no_text: String = dialogue_ui._full_text
				_drive_dialogue_action("use_tool")  # reveal offer_no
				_drive_dialogue_action("use_tool")  # terminal node -> closes
				_check(not dialogue_ui.active, "advancing past a terminal node closes the box")
				_check(offer_no_text.find("useful") != -1,
					"the 'just looking' branch's follow-up text is Harlan's distinct 2nd-option line")
				_enter_stage(53)
		53:
			# -- Re-open Harlan and take the OTHER branch (index 0), proving it leads elsewhere,
			#    and confirm the NPC/player both fully unfroze after stage 52's close() --
			if ticks < 5:
				var npc: Node = _npc_by_id("mayor_harlan")
				_check(not bool(npc.talking), "NPC unfroze after the box closed")
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.cell_to_world_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				# The player is free to walk again post-close — proven concretely in stage 56
				# (a real held-input walk) rather than here; this stage focuses on re-opening.
				player.use_tool()
				_check(dialogue_ui.active, "re-opening Harlan's dialogue works after a prior close")
				_drive_dialogue_action("use_tool")  # reveal greet
				_drive_dialogue_action("use_tool")  # advance -> founding
				_drive_dialogue_action("use_tool")  # reveal founding
				_drive_dialogue_action("use_tool")  # advance -> offer
				_drive_dialogue_action("use_tool")  # reveal offer
				_check(dialogue_ui._choice_index == 0, "choice resets to the first option on a fresh visit")
				_drive_dialogue_action("use_tool")  # confirm choice 0 -> offer_yes
				_check(dialogue_ui._node_id == "offer_yes", "the FIRST option follows ITS OWN branch")
				var offer_yes_text: String = dialogue_ui._full_text
				_check(offer_yes_text.find("Good answer") != -1,
					"the 'happy to help' branch's follow-up is Harlan's distinct 1st-option line")
				_drive_dialogue_action("use_tool")  # reveal
				_drive_dialogue_action("use_tool")  # close
				_check(not dialogue_ui.active, "second conversation closed cleanly")
				_enter_stage(54)
		54:
			# -- Marta and Scout Kael: same real interaction path, proving it's not special-cased
			#    to Harlan, each read through its own start line --
			if ticks < 5:
				var npc: Node = _npc_by_id("marta")
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.cell_to_world_center(npc_cell + Vector2i(0, -1))
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active and dialogue_ui.npc == _npc_by_id("marta"),
					"interacting with Marta opens HER dialogue")
				_check(dialogue_ui.get_node("%NameLabel").text == "Marta", "name plate shows Marta")
				_drive_dialogue_action("use_tool")  # reveal "greet"
				_drive_dialogue_action("use_tool")  # advance greet -> stocktake (not terminal yet)
				_enter_stage(55)
		55:
			# -- Marta's tree (now sitting at "stocktake", a branch point): reveal it, confirm the
			#    default (first) choice, "Let's see what you've got" — which should open the ACTUAL
			#    store rather than just printing more dialogue text, proving the stale "not open
			#    for business yet" line was replaced with a real trigger, not just reworded flavor.
			#    Deterministic (unlike the old version of this stage) since the store-opening
			#    sentinel makes the chain length fixed: reveal, then confirm.
			if ticks >= 2:
				_drive_dialogue_action("use_tool")  # reveal stocktake's branch prompt
				_check(dialogue_ui.get_node("%ChoicesBox").visible, "Marta's branch choices appear")
				_check(dialogue_ui._choice_index == 0, "first choice highlighted by default")
				_drive_dialogue_action("use_tool")  # confirm choice 0 -> OPEN_STORE sentinel
				_check(not dialogue_ui.active,
					"choosing 'Let's see what you've got' closes the dialogue box")
				_enter_stage(90)
		90:
			# -- Phase 5 Stage 2: confirm the dialogue choice actually opened the real store (not
			#    just closed the conversation) and seed enough Credits to test an affordable
			#    purchase (see class doc: Credits aren't earnable yet this stage). --
			if ticks < 5:
				return false
			if ticks == 5:
				_check(store_ui.active,
					"choosing 'Let's see what you've got' opened Marta's store")
				_check(store_ui._player == player, "store is bound to the real player")
				_check(not player.using_tool, "opening the store doesn't lock a tool-swing animation")
				_check(store_ui._index == 0, "store opens with the first catalog row highlighted")
				player.set_credits(50)
				_check(store_ui.get_node("%CreditsLabel").text == "Credits: 50",
					"credits label reflects the granted balance")
				_enter_stage(91)
		91:
			# -- Buy the first stock row (seed_mutant_potato, 8 Cr) via the real use_tool path --
			if ticks >= 2:
				var seeds_before: int = player.inventory.count_of("seed_mutant_potato")
				_drive_store_action("use_tool")
				_check(player.credits == 42,
					"buying seed_mutant_potato (8 Cr) deducted from 50 -> 42 (got %d)" % player.credits)
				_check(player.inventory.count_of("seed_mutant_potato") == seeds_before + 1,
					"the purchased seed landed in inventory via Inventory.add_item")
				_check(store_ui.get_node("%StatusLabel").text != "",
					"a purchase confirmation status message is shown")
				_enter_stage(92)
		92:
			# -- Cycle down to the pickaxe row (index 9 of the 10-item catalog) and buy a
			#    replacement tool — confirms a FRESH full-durability instance, not a stacked count --
			if ticks >= 2:
				for i in 9:
					_drive_store_action("move_down")
				_check(store_ui._index == 9, "move_down cycled all the way to the pickaxe row")
				_check(store_ui.get_node("%DescriptionLabel").text != "",
					"the highlighted row's description populates the detail label")
				var credits_before: int = player.credits
				_drive_store_action("use_tool")  # buy a replacement pickaxe (28 Cr)
				_check(player.credits == credits_before - 28,
					"pickaxe purchase deducted exactly 28 Credits (%d -> %d)" \
						% [credits_before, player.credits])
				var found_fresh_pickaxe := false
				for slot in player.inventory.slots:
					if String(slot.get("item_id", "")) == "pickaxe" \
							and int(slot.get("durability", -1)) == ItemDB.durability_max("pickaxe"):
						found_fresh_pickaxe = true
				_check(found_fresh_pickaxe,
					"a fresh full-durability replacement pickaxe landed in inventory")
				_enter_stage(93)
		93:
			# -- Insufficient funds: drop the balance too low for anything left, attempt a
			#    purchase, confirm it's refused with zero deduction and zero items granted --
			if ticks >= 2:
				player.set_credits(2)  # below every remaining stocked item's price
				_drive_store_action("move_up")  # pickaxe(9) -> axe(8), still 28 Cr, unaffordable
				_check(store_ui._index == 8, "move_up returned to the axe row")
				var credits_before: int = player.credits
				var axes_before: int = player.inventory.count_of("axe")
				_drive_store_action("use_tool")  # attempt an unaffordable purchase
				_check(player.credits == credits_before,
					"an insufficient-funds purchase attempt deducted nothing")
				_check(player.inventory.count_of("axe") == axes_before,
					"an insufficient-funds purchase attempt granted nothing")
				_check(store_ui.get_node("%StatusLabel").text != "",
					"a can't-afford status message is shown")
				_enter_stage(94)
		94:
			# -- Cycle to the trailing "Leave" row and confirm it closes the store --
			if ticks >= 2:
				for i in 2:
					_drive_store_action("move_down")  # axe(8) -> pickaxe(9) -> Leave(10)
				_check(store_ui._index == 10, "cycled down to the trailing Leave row")
				_drive_store_action("use_tool")  # confirm Leave -> closes the store
				_check(not store_ui.active, "confirming the Leave row closes the store")
				_check(not player.using_tool, "closing the store leaves no stray tool-swing lock")
				_store_check_start_pos = player.global_position
				Input.action_press("move_up")
				_enter_stage(95)
		95:
			# -- The literal "shouldn't leave the player stuck" check: real movement immediately
			#    after leaving the store, via the real held-input path --
			if ticks >= 20:
				Input.action_release("move_up")
				_check(player.global_position.y < _store_check_start_pos.y,
					"player can move immediately after leaving the store")
				_enter_stage(57)
		57:
			# -- Approach and interact with Scout Kael (same shape as stage 50's Harlan setup) --
			if ticks < 5:
				var npc: Node = _npc_by_id("scout_kael")
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.cell_to_world_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active and dialogue_ui.npc == _npc_by_id("scout_kael"),
					"interacting with Kael opens HIS dialogue")
				_check(dialogue_ui.get_node("%NameLabel").text == "Scout Kael", "name plate shows Kael")
				# Bounded (not an unconditional `while`, on principle): a real dialogue-tree bug
				# or a mis-resolved NPC should surface as a clear assertion failure below, never
				# hang the whole suite waiting on a condition that stops being true.
				var guard := 0
				while dialogue_ui.active and guard < 20:
					_drive_dialogue_action("use_tool")
					guard += 1
				_check(guard < 20, "Kael's conversation chain closed well within the safety bound")
				_check(not dialogue_ui.active, "Kael's conversation closes after its full chain")
				_check(not player.using_tool, "no stray tool-swing lock left over from any of this")
				_enter_stage(56)
		56:
			# -- Player movement/interaction genuinely still works after all that dialogue (the
			#    literal "shouldn't leave the player stuck" requirement) --
			if ticks < 5:
				player.global_position = spawn
				player.velocity = Vector2.ZERO
				Input.action_press("move_left")
				return false
			if ticks >= 30:
				Input.action_release("move_left")
				_check(player.global_position.x < spawn.x, "player can still walk after every conversation closed")
				_check(player.facing == "west", "facing still tracks input normally")
				# -- Wander check: record each NPC's cell now, verified to have moved (but stayed
				#    in-zone / off solid terrain) after simulated time in stage 61. --
				for entry in ForestEdgeLayout.npcs():
					var npc: Node = _npc_by_id(String(entry["id"]))
					_wander_start_cells[String(entry["id"])] = test_map.world_to_cell(npc.global_position)
				_enter_stage(60)
		60:
			# -- Let real time pass (well past IDLE_SECONDS_MAX) so every NPC gets at least one
			#    wander step, without touching player/day state that later stages depend on --
			if ticks >= 600:  # ~10s of physics frames
				_enter_stage(61)
		61:
			if ticks >= 5:
				var any_moved := false
				for entry in ForestEdgeLayout.npcs():
					var id := String(entry["id"])
					var home: Vector2i = entry["home"]
					var npc: Node = _npc_by_id(id)
					var cell: Vector2i = test_map.world_to_cell(npc.global_position)
					if cell != _wander_start_cells[id]:
						any_moved = true
					_check(NpcGrid.within_zone(cell, home, int(entry["wander_radius"])),
						"%s's wander stayed within its authorized zone (at %s, home %s)" % [id, cell, home])
					_check(not test_map.is_blocked_at(cell),
						"%s never wandered onto solid/blocked terrain (at %s)" % [id, cell])
				_check(any_moved, "at least one of the 3 NPCs actually wandered over ~10s")
				_enter_stage(16)
		16:
			# -- Phase 4 Stage 2: building placement, end to end (see class doc) --
			# Site: shed footprint (3,16)-(4,17) — open grass south of the creek, west of the
			# mayor's house (x8-11), on Forest Edge's ROWS. Player stands one cell north.
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(3, 15))
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				builder = main.get_node("Builder")
				_check(InputMap.has_action("build_toggle") and InputMap.has_action("build_cycle"),
					"build_toggle/build_cycle input actions are declared in project.godot")
				_check(not builder.active, "build mode starts inactive")
				_drive_builder_action("build_toggle")
				_check(builder.active and builder._preview.visible,
					"build_toggle enters placement mode and shows the preview")
				_check(builder.current_id() == "shelter_tent", "catalog starts on the tent")
				_drive_builder_action("build_cycle")
				_check(builder.current_id() == "storage_shed", "build_cycle steps to the shed")
				# Placement-validity spot checks against the live map:
				_check(structures.can_place(Vector2i(3, 16), Vector2i(2, 2)),
					"open grass site is placeable")
				_check(not structures.can_place(Vector2i(2, 11), Vector2i(2, 2)),
					"can't place onto the creek")
				_check(not structures.can_place(FARM_TEST_CELL, Vector2i.ONE),
					"can't place onto the tilled farming-test cell")
				# Forest Edge bonus materials are untouched so far: 15 wood / 8 stone / 8 scrap.
				_check(player.inventory.count_of("wood") == 15, "15 wood before building")
				var energy_before: float = player.energy
				_check(builder.confirm_placement(), "shed blueprint placed")
				_check(player.inventory.count_of("wood") == 3, "shed spent 12 wood (15 -> 3)")
				_check(player.inventory.count_of("stone") == 4, "shed spent 4 stone (8 -> 4)")
				_check(player.inventory.count_of("scrap_metal") == 6, "shed spent 2 scrap (8 -> 6)")
				_check(player.energy == energy_before - player.ENERGY_BUILD,
					"placement cost ENERGY_BUILD (%.2f -> %.2f)" % [energy_before, player.energy])
				_check(test_map.is_blocked_at(Vector2i(3, 16)) and test_map.is_blocked_at(Vector2i(4, 17)),
					"blueprint footprint registered as blocked")
				_check(not structures.can_place(Vector2i(3, 16), Vector2i(2, 2)),
					"occupied site can't be double-placed")
				_check(not farm.can_till(Vector2i(4, 16)), "can't till under a blueprint")
				_check(structures._pending.size() == 1 and structures._completed.is_empty(),
					"blueprint is pending, not complete")
				_check(not structures.is_chest_at(Vector2i(3, 16)),
					"an under-construction shed isn't storage yet")
				_check(not builder.confirm_placement(),
					"second shed refused (unaffordable and preview overlaps the first)")
				_check(player.inventory.count_of("wood") == 3, "refused placement spent nothing")
				_drive_builder_action("build_toggle")
				_check(not builder.active and not builder._preview.visible,
					"build_toggle cancels out of placement mode")
				# "Wait 1 in-game day": the same day_started signal crop growth rides.
				day_manager.skip_to_next_morning()
				_check(structures._pending.is_empty() and structures._completed.size() == 1,
					"construction completed on the next day's start")
				_check(structures.is_chest_at(Vector2i(3, 16)) and structures.is_chest_at(Vector2i(4, 17)),
					"completed shed is storage on every footprint cell")
				_enter_stage(17)
		17:
			# -- The completed shed is a real collidable body: walk the player into it --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(7, 16))
				player.velocity = Vector2.ZERO
				player.facing = "west"
				Input.action_press("move_left")
				return false
			if ticks >= 150:  # ~2.5s: plenty to cross the ~32px gap to the shed's east face
				Input.action_release("move_left")
				var shed_east_face_x := 5 * 16.0  # (top_left.x + size.x) * CELL_SIZE
				_check(player.global_position.x > shed_east_face_x,
					"completed shed collision stopped the player (x=%.1f, east face at %.1f)" \
						% [player.global_position.x, shed_east_face_x])
				_check(player.global_position.x < 110.0,
					"player actually moved toward the shed before being stopped (x=%.1f)" \
						% player.global_position.x)
				_enter_stage(18)
		18:
			# -- Shed storage opens its OWN Inventory via the existing chest UI, then gather
			#    wood (chop) so the tent build below starts from too-few resources --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(5, 17))
				player.velocity = Vector2.ZERO
				player.facing = "west"  # targets (4,17), a shed footprint cell
				return false
			if ticks == 5:
				player.use_tool()
				_check(not player.using_tool, "shed interaction is instant, no tool swing")
				_check(hud.get_node("%ChestGrid").visible, "shed storage UI opened")
				_check(hud._chest_inventory != structures.chest_inventory,
					"shed storage is its own Inventory, not the layout chest's")
				_check(hud._chest_inventory == structures.storage_inventory_at(Vector2i(4, 17)),
					"HUD is bound to the shed's real Inventory instance")
				player.use_tool()
				_check(not hud.get_node("%ChestGrid").visible, "shed UI closes on re-interaction")
				# Tent costs 6 wood; only 3 remain — chop the treeline tree at (33,2) for 3 more.
				_check(player.inventory.count_of("wood") == 3, "3 wood left, tent unaffordable")
				player.global_position = test_map.cell_to_world_center(Vector2i(32, 2))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				player.inventory.select_hotbar(2)  # axe
				_check(farm.can_chop(Vector2i(33, 2)), "tree node present east of the player")
				player.use_tool()
				_enter_stage(19)
		19:
			# -- Gathered wood affords the Shelter Tent; place + complete it too --
			if ticks >= 60:
				_check(not player.using_tool, "chop swing finished")
				_check(player.inventory.count_of("wood") == 6, "chop granted 3 wood (3 -> 6)")
				player.global_position = test_map.cell_to_world_center(Vector2i(30, 20))
				player.velocity = Vector2.ZERO
				player.facing = "south"  # tent (1x1) lands on (30,21), open grass
				_drive_builder_action("build_toggle")
				_drive_builder_action("build_cycle")  # index 1 (shed) wraps back to 0 (tent)
				_check(builder.current_id() == "shelter_tent", "build_cycle wraps around the catalog")
				_check(builder.confirm_placement(), "tent blueprint placed")
				_check(player.inventory.count_of("wood") == 0, "tent spent 6 wood")
				_check(player.energy == 96.0,
					"energy ledger holds: 100 - 1.25 (shed) - 1.5 (chop) - 1.25 (tent) = 96, got %.2f" \
						% player.energy)
				_check(test_map.is_blocked_at(Vector2i(30, 21)), "tent cell blocked while building")
				_drive_builder_action("build_toggle")
				day_manager.skip_to_next_morning()
				_check(structures._pending.is_empty() and structures._completed.size() == 2,
					"both player-built structures completed")
				_check(not structures.is_chest_at(Vector2i(30, 21)), "tent is not storage")
				_check(not farm.can_till(Vector2i(30, 21)), "completed tent cell stays untillable")
				_enter_stage(20)
		20:
			# -- Phase 4 Stage 3: sleep in the farmhouse bed -> auto-save (see class doc) --
			if ticks == 1:  # exactly once (ticks starts at 1 — see stage 24's note): these
				# mutations are NOT idempotent, unlike other stages' position-only setup.
				# Seed extra distinctive state for the round trip: replant + water the
				# farming-test plot (sleeping will advance it to stage 1/unwatered — that
				# advanced state is what must survive the reload), and drop items into BOTH
				# storage inventories (layout chest + built shed) so their contents round-trip.
				farm.plant(FARM_TEST_CELL, "mutant_potato")
				farm.water(FARM_TEST_CELL)
				player.inventory.remove_item("seed_mutant_potato", 1)  # match a real replant's cost
				structures.chest_inventory.add_item("stone", 2)
				structures.storage_inventory_at(Vector2i(3, 16)).add_item("wood", 1)
				player.set_energy(42.0)
				# Phase 5 Stage 2: Credits must round-trip too — set a fresh, distinctive value
				# here (independent of whatever balance the store stages above left behind).
				player.set_credits(37)
				# Stand one cell south of Forest Edge's bed at (18,4), facing it.
				player.global_position = test_map.cell_to_world_center(Vector2i(18, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks < 5:
				return false
			if ticks == 5:
				_check(structures.is_bed_at(Vector2i(18, 4)), "bed is at its authored cell")
				_check(not game_state.has_save(), "no save file before sleeping")
				var day_before: int = day_manager.day
				player.use_tool()  # the real bed interaction path
				_check(not player.using_tool, "bed interaction is instant, no tool swing")
				_check(day_manager.day == day_before + 1,
					"sleeping advanced the day (%d -> %d)" % [day_before, day_manager.day])
				_check(day_manager.clock_text() == "6:00 AM", "woke at 6:00 AM")
				_check(player.energy == player.max_energy, "sleeping restored full energy")
				_check(game_state.has_save(), "sleeping wrote the save file")
				_check(hud.get_node("%SaveNotice").visible, "WORLD SAVED notice appeared")
				_check(hud.get_node("%SaveNotice").text == "WORLD SAVED", "notice reads WORLD SAVED")
				saved_day = day_manager.day
				saved_position = player.global_position
				_enter_stage(21)
		21:
			# -- Simulate quitting: tear the whole game down, deliberately corrupt the resettable
			#    globals, then boot from the top exactly as a real launch does --
			if ticks < 5:
				return false
			main.queue_free()
			main = null
			game_state.chosen_settlement_id = "open_plains"  # save must restore forest_edge
			day_manager.day = 1                              # save must restore saved_day
			day_manager.minutes_into_day = 400.0
			select = (load("res://scenes/settlement_select.tscn") as PackedScene).instantiate()
			root.add_child(select)
			current_scene = select
			_enter_stage(22)
		22:
			# -- The fresh boot's resume path must skip the picker straight into main.tscn --
			if ticks < 20:  # let select._ready's deferred change_scene_to_file complete
				return false
			main = current_scene
			_check(main != null and main.name == "Main",
				"resume path skipped the picker and booted main.tscn")
			if main == null or main.name != "Main":
				_finish()
				return true
			player = main.get_node("Player")
			test_map = main.get_node("TestMap")
			farm = test_map.get_node("Farm")
			structures = test_map.get_node("Structures")
			hud = main.get_node("HUD")
			_enter_stage(23)
		23:
			# -- Everything restored: the phase milestone's literal "all state" check --
			if ticks < 10:  # a few frames so DayManager's time_changed refreshed the HUD labels
				return false
			_check(game_state.chosen_settlement_id == "forest_edge",
				"chosen settlement restored from the save")
			_check(test_map.layout == ForestEdgeLayout, "reloaded map resolved the saved layout")
			_check(day_manager.day == saved_day,
				"day restored (%d, expected %d)" % [day_manager.day, saved_day])
			_check(day_manager.clock_text() == "6:00 AM", "clock restored to the saved morning")
			_check(hud.get_node("%DayLabel").text == "Day %d" % saved_day, "HUD shows the loaded day")
			_check(player.global_position == saved_position,
				"player position restored (%s, expected %s)" % [player.global_position, saved_position])
			_check(player.facing == "north", "player facing restored")
			_check(player.energy == player.max_energy, "energy restored (full — saved after waking)")
			_check(hud.get_node("%EnergyFill").value == player.max_energy, "HUD energy bar restored")
			_check(player.credits == 37, "Credits balance restored (%d, expected 37)" % player.credits)
			_check(hud.get_node("%CreditsLabel").text == "37 Cr", "HUD credits label restored")
			# Inventory: exact contents from the played-through session, not the starting loadout
			# + settlement bonus a fresh game would have granted.
			_check(player.inventory.get_slot(0).get("item_id", "") == "hoe", "hoe back in slot 1")
			_check(int(player.inventory.get_slot(0).get("durability", -1)) == 49,
				"hoe durability (49) survived the round trip")
			_check(player.inventory.count_of("wood") == 0, "wood count (all spent building) restored")
			_check(player.inventory.count_of("mutant_potato") == 1, "harvested potato restored")
			_check(player.inventory.count_of("seed_mutant_potato") == 4,
				"seed count (5 - planted 2 + 1 bought from Marta's store) restored")
			_check(player.inventory.selected_hotbar_index == 2,
				"hotbar selection (axe, from the chop) restored")
			# World modifications:
			_check(test_map.is_tilled_at(FARM_TEST_CELL), "player-tilled cell restored")
			var plot: Dictionary = farm.get_plot(FARM_TEST_CELL)
			_check(plot.get("crop_id", "") == "mutant_potato", "planted crop restored")
			_check(int(plot.get("stage", -1)) == 1,
				"crop stage restored at 1 (watered plot advanced by the sleep's day tick)")
			_check(not bool(plot.get("watered", true)), "watered flag consumed by the day tick")
			_check(not farm.can_chop(Vector2i(33, 2)), "chopped tree stays gone after reload")
			_check(farm.can_chop(Vector2i(20, 1)), "an unchopped tree is still standing")
			# Player-built structures + storage:
			_check(structures._pending.is_empty() and structures._completed.size() == 2,
				"both completed structures restored")
			_check(structures.is_chest_at(Vector2i(3, 16)) and structures.is_chest_at(Vector2i(4, 17)),
				"restored shed is storage on its footprint")
			_check(structures.storage_inventory_at(Vector2i(3, 16)) != null and
				structures.storage_inventory_at(Vector2i(3, 16)).count_of("wood") == 1,
				"shed storage contents restored")
			_check(structures.chest_inventory.count_of("stone") == 2, "layout chest contents restored")
			_check(not structures.is_chest_at(Vector2i(30, 21)), "restored tent is not storage")
			# The _runtime_blocked overlay was re-derived from the restored structures, not
			# serialised (see save_data.gd's class doc):
			_check(test_map.is_blocked_at(Vector2i(3, 16)) and test_map.is_blocked_at(Vector2i(30, 21)),
				"restored footprints re-registered as blocked")
			_check(not farm.can_till(Vector2i(4, 16)), "can't till under the restored shed")
			_check(structures.is_bed_at(Vector2i(18, 4)), "bed present again after reload")
			# Test hygiene (hard requirement): remove the test save so repeated runs start clean.
			game_state.delete_save()
			_check(not game_state.has_save(), "test save file cleaned up")
			_enter_stage(24)
		24:
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
				_enter_stage(24)
			else:
				_enter_stage(25)
		25:
			if ticks >= 5:  # let the last queue_free() actually free before quitting
				_finish()
		_:
			pass
	return false


## Drives builder.gd's real _unhandled_input handler with a fabricated action event — exercising
## the actual input path (toggle/cycle), not just the public methods. (Input.action_press() only
## feeds the polling Input API in --script mode; it doesn't produce _unhandled_input callbacks.)
func _drive_builder_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	builder._unhandled_input(event)


## Same idea as _drive_builder_action, for dialogue_ui.gd's real _unhandled_input (Phase 5
## Stage 1) — drives "use_tool"/"move_up"/"move_down" through the actual handler rather than
## calling its private _advance()/etc. methods directly.
func _drive_dialogue_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	dialogue_ui._unhandled_input(event)


## Same idea again, for store_ui.gd's real _unhandled_input (Phase 5 Stage 2) — drives
## "use_tool"/"move_up"/"move_down" through the actual handler rather than calling its private
## _confirm()/etc. methods directly.
func _drive_store_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	store_ui._unhandled_input(event)


## Looks up a spawned NPC by its dialogue/roster id (scripts/npcs.gd's spawn list).
func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _finish() -> void:
	if failures.is_empty():
		print("RUNTIME SMOKE: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			print("RUNTIME SMOKE FAIL: %s" % failure)
		quit(1)
