extends SceneTree
## Headless runtime smoke test (separate from tests/run_tests.gd, which is for pure-logic unit
## tests): boots the real game start-to-finish and drives the actual game loop — starting from
## scenes/title_screen.tscn (the run/main_scene since the 2026-07-11 multi-slot save system;
## stages 40-41 verify the no-slots menu and its New Game hop into the picker), then Phase 4's
## pass through scenes/settlement_select.tscn (verifying the default display, then confirming a
## non-default start so the whole GameState -> layout-selection wire is genuinely exercised
## rather than assumed), landmark/collision checks on the resulting map, and the chest UI —
## before re-running Phase 2/3's original movement/camera/day-night/tool-use/farming-loop/
## pass-out checks against that same map. Simulated input/direct calls only; no display needed.
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
## wrong values, and scenes/title_screen.tscn is instantiated exactly as a real launch would —
## since the 2026-07-11 multi-slot save system, resuming is no longer an auto-skip in the picker
## but an explicit title-menu flow, so stages 22/25 drive the REAL title UI (menu shows Load
## Game because the bed save's slot exists -> cycle to it -> confirm -> the Load panel lists
## exactly the one slot with the right settlement/day -> confirm it) into main.tscn, which must
## restore crops, tilled soil, chopped-resource removals, inventory (incl. tool durability +
## hotbar selection), player position/facing/energy, both player-built structures with their
## storage contents, the chest contents, the day/clock, and the chosen settlement. Uses a
## test-only saves DIRECTORY (game_state.saves_dir, the multi-slot analogue of the old
## test-only save_path) wiped both before and after, so repeated runs never inherit stale state
## — a hard requirement, not hygiene theater — and the real user://saves slots (and the real
## legacy user://savegame.json, via a redirected game_state.legacy_save_path) are never touched.
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
##
## Phase 5 Stage 3 (stages 70-71 before the bed sleep, new checks inside stages 20/23, and
## stages 80-84 after the reload) — the whole-phase milestone's literal closed economy loop
## ("Player can farm, sell crops, earn currency, and buy seeds"), driven in ONE continuous run:
## the potato harvested through the real farming path back in stage 15 is loaded into the
## shipping box via the real facing+use_tool interaction and the loading UI's real input handler
## (stages 70-71, including empty-handed and non-crop refusals), the stage-20 bed sleep then
## resolves the overnight sale (exact +20 Cr on top of the seeded 37, itemized history entry,
## box emptied — all BEFORE that same sleep's auto-save, per structures.gd's ordering guarantee),
## stage 23 confirms all of that survived the full teardown/reload (potato gone from both
## inventory and box, 57 Cr balance, history restored), and stage 80 spends those sale-earned
## Credits at Marta's store through the real dialogue-choice path — farm -> sell -> earn -> buy,
## end to end. Stages 81-84 then cover the other Stage 3 save-shape requirement: a box loaded but
## NOT yet slept through (2 sunbloom via the real UI) is written out by a mid-session save —
## GameState.save_game called directly, because the bed path would sell the load first, which is
## precisely what this check must avoid — survives a second full teardown/reload with its pending
## contents intact, and still sells correctly (+60 Cr, second history entry) on the next real bed
## sleep after the reload.
##
## Phase 8 Stage 2 (fencing & perimeter system; stages 130-132, spliced right after the tent
## build (stage 19) and before the in-game menu (stage 100) — chosen so the Build tab's "0 wood"
## affordability check just below still holds, since 5 wood is granted and fully spent here):
## places a Wood Fence and a Wood Gate through the exact same real builder.gd flow the shed/tent
## used (catalog cycle to the new fence_wood/gate_wood entries, confirm, wait a day), then proves
## the actual walkability milestone end to end — real physical collision, not just the pure
## solid()/durability_max() data checked by tests/test_building_db.gd or the isolated
## _spawn_footprint_body/_is_footprint_occupied checks in tests/test_structures_fencing.gd: a
## completed Fence still stops the player cold (stage 131, same collision-face pattern as stage
## 17's shed check), while a completed Gate lets the player walk straight through with zero
## collision (stage 132) — and along the way, confirms a completed/unblocked Gate still can't be
## built over a second time (the _is_footprint_occupied guard, exercised live here rather than
## only in isolation).
##
## 2026-07-12 in-game tabbed menu (stages 100-101, spliced between the tent build (stage 19) and
## the shipping-box load (stage 70) — after stage 19 the inventory sits at exactly 0 wood, so the
## Build tab's affordability rows have a known, assertable state): opens scripts/menu_screen.gd
## through its real "toggle_inventory" input path, confirms it lands on the Inventory tab hosting
## the HUD's actual reparented backpack grid, that a held movement key is genuinely ignored and
## the clock pauses while it's open (main.gd's modal-gate poll), that "B"/build_toggle is REFUSED
## while the menu is open (the modal gate), cycles all three tabs with "build_cycle"/Q (checking
## the Build tab's rows carry builder.gd's exact cost strings + the missing-materials flag, and
## the Controls tab rendered its reference list), arms/disarms the Save & Return footer, closes
## with Esc, then proves the reverse exclusion: build mode works again after closing, the menu is
## refused while build mode is active, and Tab re-opens/re-closes it once nothing else is open.

const Calendar := preload("res://scripts/calendar.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const CropDB := preload("res://scripts/crop_db.gd")
const NpcSchedule := preload("res://scripts/npc_schedule.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")
## The forest_edge run's other two zones with content of their own (Path deliberately has no
## buildings/NPCs). Forest Edge uses the STANDARD town/ranch variants (settlement_db.gd's
## layout_for_zone) — the riverside variants only differ for the riverside start.
const TownLayout := preload("res://scripts/map_layouts/town_layout_standard.gd")
const RanchLayout := preload("res://scripts/map_layouts/ranch_layout_standard.gd")
const NpcGrid := preload("res://scripts/npc_grid.gd")

## Standalone-TestMap sanity check for the other 2 starts (ROADMAP Phase 4: "correct layout
## loads" for whichever start was picked, not just the one driven through the full selection ->
## main.tscn flow above). Since the zone split a standalone test_map.tscn instance is the FARM
## zone (zone_id's default) of whichever settlement is chosen, so this now checks each start's
## farm-zone map. Painted-count expectations are derived from the layout's own authored data at
## check time (fence_cells()/water_cells()/etc. — painting is a per-cell char match, so painted
## == authored is exactly the "fully painted" invariant) rather than the old hand-counted
## whole-combined-map literals the split obsoleted.
const OTHER_LAYOUT_CHECKS := [
	{"id": "open_plains", "layout": OpenPlainsLayout},
	{"id": "riverside", "layout": RiversideLayout},
]
var _other_layout_map: Node2D = null
var _other_layout_index := 0

var game_state: Node
## The title screen instance (scenes/title_screen.tscn) whichever boot most recently created it
## — the first launch (stage 40) and both simulated fresh boots (stages 21/82) drive it.
var title: Control
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
## Phase 5 Stage 3: the shipping box's crop-loading UI, fetched alongside store_ui above.
var shipping_ui: Node
## 2026-07-12: the in-game tabbed menu, fetched alongside shipping_ui above (stages 100-101).
var menu_screen: Node
## Wander-check snapshot (stage 60): each NPC's cell recorded once, compared after simulated time.
var _wander_start_cells: Dictionary = {}
## NPC ids seen away from their start cell at ANY point during stage 60's window (a step-and-
## return must still count as wandering — see stage 60's comment).
var _wander_moved: Dictionary = {}
## Position snapshot for stage 95's post-store movement check (see that stage).
var _store_check_start_pos := Vector2.ZERO
var spawn := Vector2.ZERO
var stage := 0
var stage_started_at := 0
var _chop_swings := 0
var _chop_wait_started := -1
var failures: Array[String] = []

## Snapshot taken at the moment of the stage-20 bed save, compared against the reloaded world
## in stage 23.
var saved_day := 0
var saved_position := Vector2.ZERO

## Farming-loop test plot: a plain grass cell on the farm zone's Forest Edge ROWS well clear of
## the pre-baked farmland patches, treeline/salvage, buildings, and the SW creek (row 14 is open
## grass across its whole interior width — see scripts/map_layouts/forest_edge_layout.gd's ROWS;
## re-anchored from the pre-split row 20, which now belongs to the Town zone's frame).
const FARM_TEST_CELL := Vector2i(5, 14)
const FARM_TEST_STAND_CELL := Vector2i(5, 13)
## Player-built-structure sites, re-anchored into the farm zone the same way: the 2x2 shed
## lands at (30,9)-(31,10) (stand one north of its top-left, facing south), the 1x1 tent at
## (24,14) — both verified open grass clear of farmland/creek/trees/ore/buildings.
const SHED_STAND := Vector2i(30, 8)
const SHED_CELL := Vector2i(30, 9)      # footprint top-left
const SHED_CELL_SE := Vector2i(31, 10)  # footprint bottom-right
const TENT_STAND := Vector2i(24, 13)
const TENT_CELL := Vector2i(24, 14)

## Phase 8 Stage 2 (fencing & perimeter system): two more sites on the same open row 14, well
## clear of the tent (24,14), the farming-test cell (5,14), and each other — a Wood Fence to
## prove a completed fence keeps colliding, and a Wood Gate a few cells further along to prove a
## completed gate does NOT (see stage 130-132).
const FENCE_STAND := Vector2i(27, 13)
const FENCE_CELL := Vector2i(27, 14)
const GATE_STAND := Vector2i(31, 13)
const GATE_CELL := Vector2i(31, 14)

## Where the east-wall walk (stages 6-8) starts. Every farm-local constant above survived the
## 2026-08-09 72x32 farm expansion unchanged — the re-authored Forest Edge grid deliberately
## keeps the homestead cells, the x23-35/y7-12 build clearing and the row 13-14 verge clear,
## and each was re-verified against the new ROWS — but this walk could not: it exists to run
## into the east perimeter fence, which moved from x35 to x71. Starting it 11 cells short of
## the wall keeps the stage's runtime where it was instead of adding ~15 s of walking.
const EAST_WALK_CELL := Vector2i(60, 14)
var _east_walk_start_x := 0.0

## Zone-transition plan, Stage 3: the first town round trip (stages 3/4) is driven through the
## REAL gate-cell path — the player is stood on the authored gate cell and player.gd's own
## _physics_process detection fires zone_exit_requested → main's fade → _bind_zone, the genuine
## crossing code path — rather than this file's direct main._bind_zone() shortcut. One real
## crossing per hop, each direction (farm→path→town going, town→path→farm coming home), with
## the signal counted and asserted exactly-once per hop; the REMAINING stage warps stay direct
## _warp_to() calls by design (the plan: "faster direct _bind_zone() calls are fine for the
## remaining stages once that's covered" — tools/zone_transition_smoke.gd owns proving all six
## crossings exhaustively). Routes: [from_zone, its authored gate cell, expected arrival zone];
## coordinates hold for every settlement variant (the layouts author identical gate positions).
const GATE_WALK_STAGE := 200
const ROUTE_FARM_TO_TOWN := [
	["farm", Vector2i(71, 15), "path"],
	["path", Vector2i(23, 4), "town"],
]
const ROUTE_TOWN_TO_FARM := [
	["town", Vector2i(0, 4), "path"],
	["path", Vector2i(0, 4), "farm"],
]
var _gate_route: Array = []
var _gate_next_stage := 0
## zone_exit_requested emissions observed (connected where the player is fetched, stage 1).
var _gate_exit_signals := 0
var _gate_signals_before := 0


func _initialize() -> void:
	# Godot instantiates project autoloads even in --script mode, so the real DayManager/
	# GameState already sit on root — use them (adding a duplicate gets auto-renamed and the
	# game's scripts keep reading the real ones). Note: bare global-autoload identifiers (e.g.
	# writing `GameState.foo` directly) only resolve inside scripts reached via normal scene
	# instantiation, not in this top-level --script entry file itself — hence root.get_node().
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	# Stage 3 test hygiene (hard requirement, see class doc): point the whole save system —
	# slot directory, legacy-migration source, and the pre-allocation save_path — at test-only
	# locations and wipe any stale slots a previous crashed run may have left. Redirecting
	# saves_dir means the slot the picker's confirm allocates (and every save/list/load after
	# it) stays inside the test directory; redirecting legacy_save_path means the title
	# screen's migration step can never move (and this run's cleanup can never delete) a real
	# playthrough's user://savegame.json.
	game_state.saves_dir = "user://runtime_smoke_saves"
	game_state.legacy_save_path = "user://runtime_smoke_saves/legacy.json"
	game_state.save_path = "user://runtime_smoke_saves/preboot.json"  # inert until stage 0's confirm
	_delete_test_saves()
	# Boot from the very top of the real flow: the title screen (run/main_scene since
	# 2026-07-11), whose New Game option is what reaches the settlement picker now.
	title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	stage = 40  # stages 40-41: title menu -> New Game -> picker; then the historical flow at 0
	# NOTE: node _ready callbacks have NOT run yet here — in --script mode they fire on the
	# first main-loop iteration, so all state inspection happens in the staged checks below.


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("stage %d: %s" % [stage, message])


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


## Watchdog (added after a real incident — see stage 26's note): a stage whose advance
## condition depends on something other than a plain tick count can spin forever if that
## condition never becomes true, burning near-zero CPU one frame at a time — indistinguishable
## from "still working" without watching the process directly (exactly what happened here: a
## duplicate match-arm number hijacked a transition, and the run looped silently for 12+
## minutes before it was caught by hand). MAX_TICKS_PER_STAGE is comfortably above the longest
## legitimate in-stage wait anywhere in this file (600 ticks) so it never fires on a healthy
## run, but guarantees any future stall now fails LOUDLY with the exact stuck stage instead of
## hanging the whole process indefinitely.
const MAX_TICKS_PER_STAGE := 1800
var _watchdog_tripped := false


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		push_error("runtime_smoke watchdog: stuck in stage %d for %d ticks" % [stage, ticks])
		_check(false, "TIMED OUT after %d ticks with no stage transition (watchdog)" % ticks)
		_finish()
		return true
	match stage:
		40:
			# -- First launch: the title screen with NO slots — New Game + Exit only --
			if ticks < 5:
				return false
			_check(title.mode == title.Mode.MENU, "title screen boots on its main menu")
			_check(title._menu_entries == ["New Game", "Exit"],
				"with no slots, the menu hides Load Game entirely (got %s)" \
					% str(title._menu_entries))
			_check(title._menu_index == 0, "New Game is pre-highlighted")
			_drive_title_action("use_tool")  # confirm New Game -> the settlement picker
			_enter_stage(41)
		41:
			if ticks < 15:  # let the change_scene_to_file complete
				return false
			select = current_scene
			_check(select != null and select.name == "SettlementSelect",
				"New Game transitioned to the settlement picker")
			if select == null or select.name != "SettlementSelect":
				_finish()
				return true
			_enter_stage(0)
		0:
			# Wait past startup so the selection screen's _ready() has run.
			if ticks < 5:
				return false
			_check(not game_state.has_save(),
				"no save exists at the test save_path before a settlement is confirmed")
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
			# Multi-slot (2026-07-11): confirming a settlement claims a fresh slot PATH inside
			# the (redirected) saves dir — id 1, since the test dir starts empty — but the FILE
			# stays lazy until the first auto-save (see game_state.start_new_slot's doc).
			_check(game_state.save_path == "user://runtime_smoke_saves/slot_1.json",
				"confirm allocated fresh slot 1's path (got %s)" % game_state.save_path)
			_check(not game_state.has_save(),
				"the new slot's file is not created until the first save")
			if main == null or main.name != "Main":
				_finish()
				return true
			player = main.get_node("Player")
			camera = main.get_node("GameCamera")
			day_night = main.get_node("DayNight")
			# Count real crossing signals for the Stage 3 gate-walk stages (3/4 via stage 200).
			player.zone_exit_requested.connect(
				func(_z: String, _c: Vector2i) -> void: _gate_exit_signals += 1)
			# Since the zone split main.tscn holds 4 sibling zone maps (main.zones); this smoke's
			# world refs start on the FARM zone's nodes and are re-pointed per zone as stages
			# cross (the first town round trip through the real gate walk, later trips via
			# _warp_to — the zone-transition plan's Stage 3, landed).
			test_map = main.zones["farm"]["map"]
			farm = main.zones["farm"]["farm"]
			structures = main.zones["farm"]["structures"]
			npcs = main.zones["farm"]["npcs"]
			dialogue_ui = main.get_node("DialogueUI")
			store_ui = main.get_node("StoreUI")
			shipping_ui = main.get_node("ShippingUI")
			menu_screen = main.get_node("MenuScreen")
			hud = main.get_node("HUD")
			_enter_stage(2)
		2:
			if ticks < 10:
				return false
			# -- The active FARM-zone map really is Forest Edge's, not the default --
			_check(test_map.layout == ForestEdgeLayout,
				"FarmMap resolved the Forest Edge layout (not the default Open Plains)")
			spawn = player.global_position
			_check(spawn == test_map.get_spawn_position(), "player starts on the spawn cell")
			_check(spawn == ForestEdgeLayout.cell_center(Vector2i(17, 5)),
				"spawn position matches Forest Edge's authored spawn cell (17,5)")
			_check(test_map.get_map_rect() == Rect2(0, 0, 1152, 512),
				"farm-zone map bounds are 72x32 cells (the 2026-08-09 farm expansion)")
			_check(hud.get_node("%DayLabel").text == "Spring 1", "HUD day label bound (season date)")
			_check(hud.get_node("%EnergyFill").value == 100.0, "energy bar full")
			_check(player.farm == farm and player.test_map == test_map and player.structures == structures,
				"player bound to farm/map/structures")
			_check(player.inventory.get_slot(0).get("item_id", "") == "hoe",
				"starting loadout: hoe in hotbar slot 1")
			_check(player.inventory.count_of("seed_rain_radish") == 15,
				"starting loadout: 15 rain radish seeds")
			_check(int(player.inventory.get_slot(4).get("tier", 0)) == 1 \
					and player.inventory.get_slot(4).get("item_id", "") == "scythe",
				"starting loadout: a tier-1 scythe in hotbar slot 5")
			# -- Forest Edge's "ruin materials" starting-resource bonus (ROADMAP Phase 4) --
			_check(player.inventory.count_of("wood") == 15, "Forest Edge bonus: 15 wood granted")
			_check(player.inventory.count_of("scrap_metal") == 8, "Forest Edge bonus: 8 scrap metal granted")
			_check(player.inventory.count_of("stone") == 8, "Forest Edge bonus: 8 stone granted")
			# -- The farm zone was actually painted correctly from its layout data (painting is a
			#    per-cell char match, so painted == authored is the "fully painted" invariant; the
			#    old hand-counted whole-combined-map literals died with the zone split) --
			# 2026-10-07 rendering v2: the map paints from the art/env sheets (see test_map.gd's
			# class doc) and reports what it painted via render_stats().
			var stats: Dictionary = test_map.render_stats()
			_check(int(stats["base"]) == 72 * 32, "grass base fully painted (72x32 farm zone)")
			var authored_solid := 0
			for solid_row in ForestEdgeLayout.ROWS:
				for ch in ["#", "F", "W"]:
					authored_solid += String(solid_row).count(ch)
			_check(int(stats["wall_cells"]) == authored_solid,
				"every authored solid cell ('#', 'F', 'W') has collision (%d)" % authored_solid)
			_check(int(stats["fences"]) == ForestEdgeLayout.fence_cells().size(),
				"every authored farm-zone fence cell got a fence sprite")
			_check(int(stats["water"]) > 0, "the SW creek painted onto the water layer")
			_check(int(stats["planks"]) + int(stats["road"]) == ForestEdgeLayout.dock_cells().size(),
				"every authored 'p' cell painted as decking or road")
			_check(int(stats["planks"]) > 0, "the creek footbridge is decking")
			# -- Farm-zone landmarks; the town core and ranch live in their own zones now --
			var buildings: Array[Dictionary] = ForestEdgeLayout.buildings()
			_check(buildings.size() == 4,
				"4 farm-zone buildings defined (farmhouse + chest/box/bed service row)")
			_check(structures.get_child_count() == 4, "Structures spawned one body per building")
			var kinds := {}
			for b in buildings:
				kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
			for required in ["farmhouse", "chest", "bed", "shipping_box"]:
				_check(kinds.get(required, 0) == 1, "exactly one %s" % required)
			var farmhouse: Dictionary = ForestEdgeLayout.building_at(16, 2)
			_check(String(farmhouse.get("kind", "")) == "farmhouse", "farmhouse sits north of the spawn/farmland")
			_check(structures.is_chest_at(Vector2i(16, 4)), "chest is at its authored cell")
			# -- Town zone: the town core's buildings, in ITS local frame --
			var town_kinds := {}
			for b in TownLayout.buildings():
				town_kinds[String(b["kind"])] = town_kinds.get(String(b["kind"]), 0) + 1
			for required in ["mayor_house", "store", "bulletin_board"]:
				_check(town_kinds.get(required, 0) == 1, "exactly one %s (town zone)" % required)
			_check(town_kinds.get("shack", 0) == 4, "4 settler shacks (town zone)")
			# Milestone B: plus the Town Works buildings (Doc's tent until the clinic is rebuilt).
			_check(main.zones["town"]["structures"].get_child_count()
					== TownLayout.buildings().size() + main.zones["town"]["structures"]._works.size(),
				"town Structures spawned one body per town building (and per Town Works building)")
			_check(main.zones["town"]["structures"].has_works_building("doc_tent"),
				"Doc's tent stands by the ruined clinic on a new game")
			var mayor: Dictionary = TownLayout.building_at(8, 1)
			_check(String(mayor.get("kind", "")) == "mayor_house",
				"mayor's house sits in the town core (town-local frame)")
			# -- Ranch zone: the compound's three scenery buildings --
			var ranch_kinds := {}
			for b in RanchLayout.buildings():
				ranch_kinds[String(b["kind"])] = ranch_kinds.get(String(b["kind"]), 0) + 1
			for required in ["ranch_house", "ranch_barn", "ranch_coop"]:
				_check(ranch_kinds.get(required, 0) == 1, "exactly one %s (ranch zone)" % required)
			_check(main.zones["ranch"]["structures"].get_child_count() == RanchLayout.buildings().size(),
				"ranch Structures spawned one body per ranch building")
			# -- Phase 5 Stage 1 + MAPS.md §3: NPC rosters live per zone since the split —
			#    none on the farm, the 3 town-core NPCs in town, the ranch keeper in the ranch --
			_check(npcs.npcs().size() == 0, "no NPC lives in the farm zone")
			for zone_id in ["town", "ranch"]:
				var zmap: Node2D = main.zones[zone_id]["map"]
				var entries: Array = zmap.layout.npcs()
				_check(main.zones[zone_id]["npcs"].npcs().size() == entries.size(),
					"%s zone spawned its full %d-NPC roster" % [zone_id, entries.size()])
				for entry in entries:
					var npc: Node = _npc_by_id(String(entry["id"]), zone_id)
					_check(npc != null, "npc '%s' exists" % entry["id"])
					if npc != null:
						_check(zmap.world_to_cell(npc.global_position) == entry["home"],
							"npc '%s' spawned at its authored home cell %s" % [entry["id"], entry["home"]])
			# Stage 3's town visit arrives through the REAL gate walk (farm→path→town), not a
			# direct _bind_zone shortcut — see GATE_WALK_STAGE's doc.
			_begin_gate_walk(ROUTE_FARM_TO_TOWN, 3)
		3:
			# -- Basic collision on buildings works: walk the player into the mayor's house.
			#    Town-zone content since the split: we arrive here via the real gate-cell walk
			#    (stage 200), already town-bound, and compare in the town map's LOCAL frame,
			#    since the zone sits at a sibling world offset. --
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(Vector2i(5, 2))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				Input.action_press("move_right")
				return false
			if ticks >= 150:  # ~2.5s: plenty to cross the ~32px gap to the building's west face
				Input.action_release("move_right")
				var x_local: float = test_map.to_local(player.global_position).x
				var mayor_west_face_x: float = 8 * 16.0  # town-local top_left.x * CELL_SIZE
				_check(x_local < mayor_west_face_x,
					"mayor's house collision stopped the player (local x=%.1f, west face at %.1f)" \
						% [x_local, mayor_west_face_x])
				_check(x_local > 90.0,
					"player actually moved toward the building before being stopped (local x=%.1f)" \
						% x_local)
				# Home again the same way: the real west gate walk (town→path→farm).
				_begin_gate_walk(ROUTE_TOWN_TO_FARM, 4)
		4:
			# -- Chest interaction: opens/toggles a real second Inventory via the HUD --
			#    (Arrived farm-bound via the real gate walk home, stage 200.)
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(Vector2i(16, 5))
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
				# 2026-10-07 Milestone B: chests open the two-pane storage screen (storage_ui.gd).
				_check(main.storage_ui.active, "chest storage screen opened")
				_check(main.storage_ui.storage() == structures.chest_inventory,
					"the storage screen is bound to Structures' real chest Inventory instance")
				player.use_tool()  # interact again: should close it
				_check(not main.storage_ui.active, "the storage screen closes on a second interaction")
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
				# Re-baseline energy for the exact per-action ledger stages 11-13 assert: the
				# ~half-a-game-minute this stage idled at the teleported midnight sat inside the
				# forced-sleep rules' sleepy window (2026-07-11), correctly draining a fraction
				# of energy — real behaviour, artificial clock position. (Can't pause instead:
				# main.gd's _process re-derives time_paused from the modal gate every frame.)
				player.set_energy(player.max_energy)
				# Walk east along row 14, NOT the spawn's row: the east wall has its gate-break
				# to the Path zone on rows 15-16, so a walk on those rows would warp zones
				# instead of hitting the fence. Row 14 (the buried-street verge) is open clear
				# to the wall. Started from EAST_WALK_CELL rather than the spawn column since
				# the 72-wide expansion: at 56 px/s a walk from the spawn would need ~15 real
				# seconds to reach the far wall, and this stage is about the wall and the
				# camera clamp, not how long the map takes to cross.
				player.global_position = test_map.get_global_cell_center(EAST_WALK_CELL)
				_east_walk_start_x = player.global_position.x
				player.velocity = Vector2.ZERO
				Input.action_press("move_right")
				_enter_stage(7)
		7:
			if ticks >= 120:  # ~2s of walking east
				_check(player.global_position.x > _east_walk_start_x + 60.0,
					"player walked east (x %.1f from %.1f)" \
						% [player.global_position.x, _east_walk_start_x])
				_check(player.facing == "east", "facing tracked input")
				_check(player.get_node("Sprite").animation == &"walk_east", "walk_east playing")
				_enter_stage(8)
		8:
			if ticks >= 300:  # ~5 more seconds: must have hit the east perimeter fence by now
				var x := player.global_position.x
				var fence_face_x := 71 * 16.0
				_check(x > _east_walk_start_x + 120.0 and x < fence_face_x,
					"border fence stopped the player (x=%.1f, wall face at %.1f)" % [x, fence_face_x])
				Input.action_release("move_right")
				# Camera clamp: the farm zone is 72x32 cells = 1152x512 px since the 2026-08-09
				# expansion (was 36x16/576x256; the stale comment that used to sit here still
				# described the PRE-zone-split 36x49 combined map, and the loose y bound it
				# implied). View is 320x192 -> half=(160,96), so the clamped centre band is
				# x in [160, 1152-160=992] and y in [96, 512-96=416]. The player is pinned
				# against the east wall here, so x must sit exactly on its upper limit; the
				# row-14 walk puts y mid-band, and 416 is now the farm's REAL upper bound.
				_check(absf(camera.global_position.x - 992.0) < 1.0,
					"camera clamped at east limit (x=%.1f)" % camera.global_position.x)
				_check(camera.global_position.y >= 96.0 and camera.global_position.y <= 416.0,
					"camera y inside the farm's real clamp band (y=%.1f)" % camera.global_position.y)
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
				player.global_position = test_map.get_global_cell_center(FARM_TEST_STAND_CELL)
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
				player.inventory.select_hotbar(5)  # seed_rain_radish (see _give_starting_loadout)
				_check(player.inventory.get_slot(5).get("item_id", "") == "seed_rain_radish",
					"seeds are in hotbar slot 6")
				player.use_tool()  # plant
				_enter_stage(12)
		12:
			if ticks >= 60:
				_check(not player.using_tool, "plant swing finished")
				var plot: Dictionary = farm.get_plot(FARM_TEST_CELL)
				_check(plot.get("crop_id", "") == "rain_radish", "seed planted rain radish")
				_check(int(plot.get("stage", -1)) == 0, "freshly planted crop starts at stage 0")
				_check(player.inventory.count_of("seed_rain_radish") == 14, "one seed consumed")
				_check(player.energy == 99.0, "planting is free (2026-10-07: Stardew-faithful)")
				player.inventory.select_hotbar(1)  # watering_can
				player.use_tool()  # water
				_enter_stage(13)
		13:
			if ticks >= 60:
				_check(not player.using_tool, "water swing finished")
				_check(farm.is_watered(FARM_TEST_CELL), "watering can watered the crop")
				_check(player.energy == 98.0, "watering cost 1 energy (99 -> 98)")
				_check(int(player.inventory.get_slot(1).get("water", -1)) == 39,
					"watering can used one of its 40 charges")
				var growth_stages := CropDB.total_days("rain_radish") + 1
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
				var potatoes_before: int = player.inventory.count_of("rain_radish")
				_check(potatoes_before == 0, "no rain radish in inventory before harvest")
				player.inventory.select_hotbar(0)  # harvest ignores selection, but pick something valid
				player.use_tool()  # harvest
				_enter_stage(15)
		15:
			if ticks >= 60:
				_check(not player.using_tool, "harvest swing finished")
				_check(player.inventory.count_of("rain_radish") == 1,
					"harvested rain radish landed in inventory")
				_check(farm.get_plot(FARM_TEST_CELL).is_empty(),
					"plot cleared back to bare soil after harvest")
				_check(test_map.is_tilled_at(FARM_TEST_CELL),
					"cell stays tilled (replantable) after harvest, doesn't revert to grass")
				# -- Pass-out-at-zero-energy check --
				var day_before: int = day_manager.day
				_check(not game_state.has_save(), "no save file exists before the pass-out")
				player.set_energy(3.0)
				player.set_energy(-50.0)  # crosses from positive to <=0 -> should pass out
				_check(day_manager.day == day_before + 1,
					"energy hitting zero triggered a day skip (day %d -> %d)" % [day_before, day_manager.day])
				_check(day_manager.clock_text() == "6:00 AM", "woke up at 6:00 AM")
				_check(player.energy == player.max_energy, "waking up restores full energy")
				# 2026-07-11 forced-sleep spec: progress saves when the player falls asleep OR
				# passes out — the zero-energy collapse must now auto-save like the bed does.
				_check(game_state.has_save(), "the zero-energy pass-out auto-saved")
				# Clean it up so stage 20's "the bed writes the save" check still starts from a
				# provably save-free state.
				game_state.delete_save()
				_enter_stage(50)
		50:
			# -- Phase 5 Stage 1: approach Mayor Harlan and open the dialogue box (see class doc's
			#    NPC section). Stands one cell south of wherever Harlan's actual live cell is
			#    (rather than his authored home) so this check is robust even if he's already
			#    taken a wander step by the time this stage runs.
			if ticks < 5:
				_warp_to("town")  # zone split: the town-core NPCs live in the Town zone now
				var npc: Node = _npc_by_id("mayor_harlan")
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
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
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				# The player is free to walk again post-close — proven concretely in stage 56
				# (a real held-input walk) rather than here; this stage focuses on re-opening.
				player.use_tool()
				_check(dialogue_ui.active, "re-opening Harlan's dialogue works after a prior close")
				# Milestone B (v2 dialogue): the intro tree plays once; a second chat the same day is
				# one of his short repeat lines, and (Harlan having no service menu) then closes.
				_check(dialogue_ui._node_id == "_line", "a second visit opens on today's line, not the intro")
				_check(DialogueDB.repeat_lines("mayor_harlan").has(dialogue_ui._full_text),
					"the same day, it's one of Harlan's repeat lines")
				_drive_dialogue_action("use_tool")  # reveal
				_drive_dialogue_action("use_tool")  # close
				_check(not dialogue_ui.active, "the repeat line closes the conversation")
				# The intro's other branch, through the scripted entry point (a fresh open, so the
				# highlighted choice must reset).
				dialogue_ui.open_dialogue_at(_npc_by_id("mayor_harlan"), "offer")
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
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, -1))
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
			# -- Buy the first spring stock row (seed_rain_radish, 12 Cr) via the real use_tool
			#    path (2026-10-07: Marta's shelf is seasonal — spring seeds, then staples) --
			if ticks >= 2:
				_check(store_ui._row_ids[0] == "seed_rain_radish", "spring shelf starts with radish seeds")
				var seeds_before: int = player.inventory.count_of("seed_rain_radish")
				_drive_store_action("use_tool")
				_check(player.credits == 38,
					"buying seed_rain_radish (12 Cr) deducted from 50 -> 38 (got %d)" % player.credits)
				_check(player.inventory.count_of("seed_rain_radish") == seeds_before + 1,
					"the purchased seed landed in inventory via Inventory.add_item")
				_check(store_ui.get_node("%StatusLabel").text != "",
					"a purchase confirmation status message is shown")
				_enter_stage(92)
		92:
			# -- Cycle down to the purified-water row (index 7 of the spring shelf) and
			#    buy one --
			if ticks >= 2:
				for i in 7:
					_drive_store_action("move_down")
				_check(store_ui._index == 7, "move_down cycled to the purified water row")
				_check(store_ui._row_ids[7] == "purified_water", "row 7 is purified water")
				_check(store_ui.get_node("%DescriptionLabel").text != "",
					"the highlighted row's description populates the detail label")
				var credits_before: int = player.credits
				var water_before: int = player.inventory.count_of("purified_water")
				_drive_store_action("use_tool")  # 25 Cr
				_check(player.credits == credits_before - 25,
					"purified water deducted exactly 25 Credits (%d -> %d)" % [credits_before, player.credits])
				_check(player.inventory.count_of("purified_water") == water_before + 1,
					"the purchased water landed in inventory")
				_enter_stage(93)
		93:
			# -- Insufficient funds: drop the balance too low for anything left, attempt a
			#    purchase, confirm it's refused with zero deduction and zero items granted --
			if ticks >= 2:
				player.set_credits(2)  # below every stocked item's price
				_drive_store_action("move_up")  # purified_water(7) -> preserved_food(6), 40 Cr
				_check(store_ui._index == 6, "move_up returned to the preserved food row")
				var credits_before: int = player.credits
				var rations_before: int = player.inventory.count_of("preserved_food")
				_drive_store_action("use_tool")  # attempt an unaffordable purchase
				_check(player.credits == credits_before,
					"an insufficient-funds purchase attempt deducted nothing")
				_check(player.inventory.count_of("preserved_food") == rations_before,
					"an insufficient-funds purchase attempt granted nothing")
				_check(store_ui.get_node("%StatusLabel").text != "",
					"a can't-afford status message is shown")
				_enter_stage(94)
		94:
			# -- Cycle to the trailing "Leave" row and confirm it closes the store --
			if ticks >= 2:
				# The trailing "" row is Leave; find it rather than counting, so adding a staple to
				# the shelf (Milestone C added three) doesn't silently turn this into a purchase.
				var leave_row: int = store_ui._row_ids.size() - 1
				_check(store_ui._row_ids[leave_row] == "", "the store's last row is Leave")
				for i in leave_row - store_ui._index:
					_drive_store_action("move_down")  # preserved_food(6) -> ... -> Leave
				_check(store_ui._index == leave_row, "cycled down to the trailing Leave row")
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
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
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
				_warp_to("farm")  # home from the town visits; the walk check runs at the spawn
				player.global_position = spawn
				player.velocity = Vector2.ZERO
				Input.action_press("move_left")
				return false
			if ticks >= 30:
				Input.action_release("move_left")
				_check(player.global_position.x < spawn.x, "player can still walk after every conversation closed")
				_check(player.facing == "west", "facing still tracks input normally")
				# -- Wander check: record each NPC's cell now, verified to have moved (but stayed
				#    in-zone / off solid terrain) after simulated time in stage 61. Rosters are
				#    per zone since the split (town 3 + ranch 1); inactive zones aren't paused,
				#    so NPCs keep wandering there while the player stands on the farm. --
				# Pin the clock early in the home-waypoint hour: every scheduled NPC's first
				# waypoint is home until 7:00 (Kael) / 7:30 (Silas), and at Stardew's pace (10 game
				# minutes per 7 real seconds) the window below must not cross those departures.
				day_manager.minutes_into_day = 6.0 * 60.0 + 5.0
				for zone_id in ["town", "ranch"]:
					var zmap: Node2D = main.zones[zone_id]["map"]
					for entry in zmap.layout.npcs():
						var npc: Node = _npc_by_id(String(entry["id"]), zone_id)
						_wander_start_cells[String(entry["id"])] = \
							zmap.world_to_cell(npc.global_position)
				_enter_stage(60)
		60:
			# -- Let real time pass (well past IDLE_SECONDS_MAX) so every NPC gets at least one
			#    wander step, without touching player/day state that later stages depend on.
			#    Movement is accumulated DURING the window, not compared endpoint-to-endpoint:
			#    with 2-6s idles an NPC takes ~2 steps in these ~10s, and a step-out-then-
			#    step-back ends exactly where it started — the old endpoint comparison read
			#    that as "never moved" and intermittently failed for real (all 4 NPCs happening
			#    to round-trip, observed 2026-07-19), even though every NPC genuinely wandered. --
			for zone_id in ["town", "ranch"]:
				var zmap: Node2D = main.zones[zone_id]["map"]
				for entry in zmap.layout.npcs():
					var id := String(entry["id"])
					var npc: Node = _npc_by_id(id, zone_id)
					if zmap.world_to_cell(npc.global_position) != _wander_start_cells[id]:
						_wander_moved[id] = true
			if ticks >= 600:  # ~10s of physics frames
				_enter_stage(61)
		61:
			if ticks >= 5:
				for zone_id in ["town", "ranch"]:
					var zmap: Node2D = main.zones[zone_id]["map"]
					for entry in zmap.layout.npcs():
						var id := String(entry["id"])
						var home: Vector2i = entry["home"]
						var npc: Node = _npc_by_id(id, zone_id)
						var cell: Vector2i = zmap.world_to_cell(npc.global_position)
						# A scheduled NPC ambles around its CURRENT waypoint (home is just the
						# first); one walking between waypoints is exempt until it arrives.
						var anchor: Vector2i = home
						if NpcSchedule.has_schedule(id):
							anchor = NpcSchedule.current_waypoint(NpcSchedule.schedule_for(id),
								day_manager.minutes_into_day)
						if not bool(npc.get("_traveling")):
							_check(NpcGrid.within_zone(cell, anchor, int(entry["wander_radius"])),
								"%s's wander stayed within its authorized zone (at %s, anchor %s)" % [id, cell, anchor])
						_check(not zmap.is_blocked_at(cell),
							"%s never wandered onto solid/blocked terrain (at %s)" % [id, cell])
				_check(not _wander_moved.is_empty(),
					"at least one NPC actually wandered at some point over ~10s")
				_enter_stage(62)
		62:
			# -- MAPS.md §3: visit the Ranch/Sanctuary compound and open the keeper's dialogue
			#    through the real facing+use_tool path (same shape as stages 50/54/57). Since
			#    the zone split the compound is its own zone: Silas spawning from the RANCH
			#    zone's roster (not town's) is what "he's in the compound, not misplaced up in
			#    town" means now — the old absolute-row check (y >= 36) died with the combined
			#    map's single frame. --
			if ticks < 5:
				_warp_to("ranch")
				var npc: Node = _npc_by_id("rancher_silas")
				_check(npc != null, "the ranch keeper spawned in the RANCH zone's roster")
				if npc == null:
					_finish()
					return true
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				_check(test_map.get_map_rect().has_point(test_map.cell_to_world_center(npc_cell)),
					"Silas stands inside the ranch compound's own map (cell %s)" % npc_cell)
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				var npc: Node = _npc_by_id("rancher_silas")
				var energy_before: float = player.energy
				player.use_tool()
				_check(dialogue_ui.active and dialogue_ui.npc == npc,
					"interacting with Silas opens HIS dialogue")
				_check(dialogue_ui.get_node("%NameLabel").text == "Silas", "name plate shows Silas")
				_check(player.energy == energy_before, "ranch dialogue costs no energy (like the town NPCs)")
				# Drive to the branch, take the "can I buy stock" option (index 0), and confirm
				# its honest "not yet" follow-up (the Marta-Stage-1 precedent: no livestock shop
				# wired this pass) before the box closes.
				_drive_dialogue_action("use_tool")  # reveal greet
				_drive_dialogue_action("use_tool")  # advance greet -> stock
				_drive_dialogue_action("use_tool")  # reveal stock
				_drive_dialogue_action("use_tool")  # advance stock -> offer (branch)
				_check(dialogue_ui._node_id == "offer", "reached Silas's branch point")
				_drive_dialogue_action("use_tool")  # reveal the branch prompt
				_check(dialogue_ui.get_node("%ChoicesBox").visible, "Silas's branch choices appear")
				_drive_dialogue_action("use_tool")  # confirm choice 0 -> not_yet
				_check(dialogue_ui._node_id == "not_yet",
					"the 'buy stock' option led to the honest not-open-yet line")
				var not_yet_text: String = dialogue_ui._full_text
				_check(not_yet_text.find("barn") != -1 or not_yet_text.find("coop") != -1,
					"the not-yet line points the player at building a barn/coop first")
				_drive_dialogue_action("use_tool")  # reveal not_yet
				_drive_dialogue_action("use_tool")  # terminal -> close
				_check(not dialogue_ui.active, "Silas's conversation closes cleanly")
				_check(not player.using_tool, "no stray tool-swing lock from the ranch visit")
				_enter_stage(16)
		16:
			# -- Phase 4 Stage 2: building placement, end to end (see class doc) --
			# Site: shed footprint SHED_CELL..SHED_CELL_SE — open grass on the farm zone's east
			# side, clear of farmland/creek/trees/ore. Player stands one cell north, facing south.
			if ticks < 5:
				_warp_to("farm")  # home from the ranch visit: building happens on the farm
				player.global_position = test_map.get_global_cell_center(SHED_STAND)
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
				_check(structures.can_place(SHED_CELL, Vector2i(2, 2)),
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
				_check(test_map.is_blocked_at(SHED_CELL) and test_map.is_blocked_at(SHED_CELL_SE),
					"blueprint footprint registered as blocked")
				_check(not structures.can_place(SHED_CELL, Vector2i(2, 2)),
					"occupied site can't be double-placed")
				_check(not farm.can_till(Vector2i(31, 9)), "can't till under a blueprint")
				_check(structures._pending.size() == 1 and structures._completed.is_empty(),
					"blueprint is pending, not complete")
				_check(not structures.is_chest_at(SHED_CELL),
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
				_check(structures.is_chest_at(SHED_CELL) and structures.is_chest_at(SHED_CELL_SE),
					"completed shed is storage on every footprint cell")
				_enter_stage(17)
		17:
			# -- The completed shed is a real collidable body: walk the player into it --
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(Vector2i(33, 9))
				player.velocity = Vector2.ZERO
				player.facing = "west"
				Input.action_press("move_left")
				return false
			if ticks >= 150:  # ~2.5s: plenty to cross the ~16px gap to the shed's east face
				Input.action_release("move_left")
				var shed_east_face_x := 32 * 16.0  # (top_left.x + size.x) * CELL_SIZE
				_check(player.global_position.x > shed_east_face_x,
					"completed shed collision stopped the player (x=%.1f, east face at %.1f)" \
						% [player.global_position.x, shed_east_face_x])
				_check(player.global_position.x < 530.0,
					"player actually moved toward the shed before being stopped (x=%.1f)" \
						% player.global_position.x)
				_enter_stage(18)
		18:
			# -- Shed storage opens its OWN Inventory via the existing chest UI, then gather
			#    wood (chop) so the tent build below starts from too-few resources --
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(Vector2i(32, 10))
				player.velocity = Vector2.ZERO
				player.facing = "west"  # targets (31,10), a shed footprint cell
				return false
			if ticks == 5:
				player.use_tool()
				_check(not player.using_tool, "shed interaction is instant, no tool swing")
				_check(main.storage_ui.active, "shed storage screen opened")
				_check(main.storage_ui.storage() != structures.chest_inventory,
					"shed storage is its own Inventory, not the layout chest's")
				_check(main.storage_ui.storage() == structures.storage_inventory_at(SHED_CELL_SE),
					"the storage screen is bound to the shed's real Inventory instance")
				player.use_tool()
				_check(not main.storage_ui.active, "the shed screen closes on re-interaction")
				# Tent costs 6 wood; only 3 remain — chop the treeline tree at (33,2) for 3 more.
				_check(player.inventory.count_of("wood") == 3, "3 wood left, tent unaffordable")
				player.global_position = test_map.get_global_cell_center(Vector2i(32, 2))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				player.inventory.select_hotbar(2)  # axe
				var objects: Node = test_map.get_node("Objects")
				_check(String(objects.kind_at(Vector2i(33, 2))).begins_with("tree"),
					"tree present east of the player")
				_chop_swings = 0
				player.use_tool()
				_chop_swings += 1
				_enter_stage(19)
		19:
			# -- 2026-10-07 world objects: a tree takes several hits (10 HP, tier-1 axe = 1 dmg),
			#    topples, leaves a stump and spills its wood as pickups. Keep swinging until it
			#    falls, then let the drops land and sweep them into the backpack. --
			var objects19: Node = test_map.get_node("Objects")
			if String(objects19.kind_at(Vector2i(33, 2))).begins_with("tree"):
				if not player.using_tool:
					player.use_tool()
					_chop_swings += 1
				return false
			if _chop_wait_started < 0:
				_chop_wait_started = ticks
				_check(_chop_swings == 10, "the tree fell on the 10th swing (took %d)" % _chop_swings)
				_check(String(objects19.kind_at(Vector2i(33, 2))) == "stump_ashwood" \
						or String(objects19.kind_at(Vector2i(33, 2))) == "stump_pine",
					"a stump is left behind")
				return false
			if ticks - _chop_wait_started < 90:
				return false
			objects19.collect_all_pickups(player.inventory)
			# -- Gathered wood affords the Shelter Tent; place + complete it too --
			if true:
				_check(not player.using_tool, "chop swing finished")
				_check(player.inventory.count_of("wood") >= 3 + 8, "the felled tree dropped 8+ wood")
				player.inventory.remove_item("wood", player.inventory.count_of("wood") - 6)
				player.global_position = test_map.get_global_cell_center(TENT_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "south"  # tent (1x1) lands on TENT_CELL, open grass
				_drive_builder_action("build_toggle")
				# Phase 8 Stage 1 grew the catalog to 12 entries, Stage 2's 4 fence/gate entries
				# grew it to 16, and Phase 8 livestock adds Barn/Coop at indices 2 and 3:
				# from index 1 (the shed, still selected from stage 16), cycling all the way
				# around back to index 0 now takes 17 presses,
				# not 1 — this still exercises the real wraparound (Q past the last entry lands
				# back on the first), just over the bigger catalog.
				for i in 17:
					_drive_builder_action("build_cycle")
				_check(builder.current_id() == "shelter_tent", "build_cycle wraps around the catalog")
				_check(builder.confirm_placement(), "tent blueprint placed")
				_check(player.inventory.count_of("wood") == 0, "tent spent 6 wood")
				_check(player.energy == 87.5,
					"energy ledger holds: 100 - 1.25 (shed) - 10 x 1 (chops) - 1.25 (tent) = 87.5, got %.2f" \
						% player.energy)
				_check(test_map.is_blocked_at(TENT_CELL), "tent cell blocked while building")
				_drive_builder_action("build_toggle")
				day_manager.skip_to_next_morning()
				_check(structures._pending.is_empty() and structures._completed.size() == 2,
					"both player-built structures completed")
				_check(not structures.is_chest_at(TENT_CELL), "tent is not storage")
				_check(not farm.can_till(TENT_CELL), "completed tent cell stays untillable")
				_enter_stage(130)
		130:
			# -- Phase 8 Stage 2 (fencing & perimeter system), part 1: place a Wood Fence and a
			#    Wood Gate through the same real builder.gd flow as the shed/tent above, then
			#    complete both overnight. Wood is granted directly (the gather loop itself is
			#    already proven by stage 18's chop) — same "seed distinctive state to exercise"
			#    convention stage 90 uses for Credits. --
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(FENCE_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				# Grant exactly enough for both (2 + 3 = 5) so wood lands back at exactly 0
				# afterward — preserving stage 100's "0 wood after the tent build" invariant for
				# the Build tab's missing-materials check, rather than leaving a residual amount
				# that would only coincidentally still read as "missing" for the Shelter Cabin row.
				player.inventory.add_item("wood", 5)
				_check(not builder.active, "build mode starts inactive (stage 130)")
				_drive_builder_action("build_toggle")
				# From index 0 (shelter_tent, stage 19 left it wrapped there) to fence_wood
				# (index 14 of 18): 14 presses.
				for i in 14:
					_drive_builder_action("build_cycle")
				_check(builder.current_id() == "fence_wood", "build_cycle reached the Wood Fence")
				_check(structures.can_place(FENCE_CELL, Vector2i.ONE), "fence site is placeable")
				var wood_before: int = player.inventory.count_of("wood")
				_check(builder.confirm_placement(), "fence blueprint placed")
				_check(player.inventory.count_of("wood") == wood_before - 2, "fence spent 2 wood")
				_check(test_map.is_blocked_at(FENCE_CELL),
					"a construction site blocks like anything else while building")
				# Reposition for the gate, still in the same build-mode session — 3 more presses
				# from fence_wood (14) to gate_wood (17).
				player.global_position = test_map.get_global_cell_center(GATE_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "south"
				for i in 3:
					_drive_builder_action("build_cycle")
				_check(builder.current_id() == "gate_wood", "build_cycle reached the Wood Gate")
				_check(structures.can_place(GATE_CELL, Vector2i.ONE), "gate site is placeable")
				wood_before = player.inventory.count_of("wood")
				_check(builder.confirm_placement(), "gate blueprint placed")
				_check(player.inventory.count_of("wood") == wood_before - 3, "gate spent 3 wood")
				_check(test_map.is_blocked_at(GATE_CELL),
					"the gate's construction site blocks too, while building")
				_drive_builder_action("build_toggle")
				day_manager.skip_to_next_morning()
				_check(structures._pending.is_empty() and structures._completed.size() == 4,
					"both the fence and gate completed alongside the earlier shed/tent")
				_check(test_map.is_blocked_at(FENCE_CELL),
					"a completed solid Fence stays blocked")
				_check(not test_map.is_blocked_at(GATE_CELL),
					"a completed non-solid Gate is unblocked — the literal walkability milestone")
				# The gap this opens, and the guard that closes it (structures.gd's
				# _is_footprint_occupied, unit-tested in isolation by
				# tests/test_structures_fencing.gd): an unblocked Gate cell must still refuse a
				# second building on top of it.
				_check(not structures.can_place(GATE_CELL, Vector2i.ONE),
					"can't rebuild on top of a completed, unblocked Gate")
				_check(not structures.can_place(FENCE_CELL, Vector2i.ONE),
					"can't rebuild on top of a completed Fence either")
				# Approach the fence from the west along row 14 and confirm real physical
				# collision stops the player (same pattern as stage 17's shed check).
				player.global_position = test_map.get_global_cell_center(Vector2i(25, 14))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				Input.action_press("move_right")
				_enter_stage(131)
		131:
			# -- The completed Fence is a real collidable body: walking east into it stops --
			if ticks >= 200:
				Input.action_release("move_right")
				var fence_west_face_x := FENCE_CELL.x * 16.0
				_check(player.global_position.x < fence_west_face_x,
					"completed fence collision stopped the player (x=%.1f, west face at %.1f)" \
						% [player.global_position.x, fence_west_face_x])
				_check(player.global_position.x > 410.0,
					"player actually moved toward the fence before being stopped (x=%.1f)" \
						% player.global_position.x)
				# Approach the gate the same way, from just west of it.
				player.global_position = test_map.get_global_cell_center(Vector2i(29, 14))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				Input.action_press("move_right")
				_enter_stage(132)
		132:
			# -- The completed Gate has NO collision: walking east straight through it works —
			#    the actual end-to-end proof of Phase 8 Stage 2's walkability milestone. --
			if ticks >= 250:
				Input.action_release("move_right")
				var gate_east_face_x := (GATE_CELL.x + 1) * 16.0
				_check(player.global_position.x > gate_east_face_x + 20.0,
					"the player walked straight through the completed gate with no collision " \
						+ "(x=%.1f, gate east face at %.1f)" \
						% [player.global_position.x, gate_east_face_x])
				_enter_stage(100)
		100:
			# -- 2026-07-12 in-game tabbed menu, part 1 (see class doc): open via the real
			#    "toggle_inventory" input path, frozen player + paused clock, B refused while
			#    open, tab cycling with exact Build-tab affordability rows (0 wood here, so both
			#    catalog entries are assertably unaffordable), quit-footer arm/disarm, Esc close.
			if ticks < 5:
				return false
			if ticks == 5:
				_check(not menu_screen.active, "the menu starts closed")
				_check(not menu_screen.get_node("%Box").visible, "menu panel starts hidden")
				_drive_menu_action("toggle_inventory")
				_check(menu_screen.active, "Tab (toggle_inventory) opens the menu")
				_check(menu_screen.get_node("%Box").visible, "the menu panel is visible")
				_check(menu_screen.tab_index == menu_screen.TAB_INVENTORY,
					"the menu always opens on the Inventory tab")
				_check(hud.inventory_grid.get_parent() == menu_screen.inventory_tab,
					"the HUD's backpack grid was reparented into the Inventory tab (re-hosted)")
				_check(hud.inventory_grid.visible and menu_screen.inventory_tab.visible,
					"the re-hosted backpack grid is showing")
				Input.action_press("move_right")
				return false
			if ticks < 12:
				return false
			if ticks == 12:
				_check(player.velocity == Vector2.ZERO,
					"player stays frozen while the menu is open despite a held movement key")
				Input.action_release("move_right")
				_check(day_manager.time_paused, "an open menu pauses the clock (true modal)")
				# THE gate check this session's feature demands: B must NOT engage build mode
				# underneath the open menu — driven through builder.gd's real input handler.
				_drive_builder_action("build_toggle")
				_check(not builder.active,
					"build_toggle is REFUSED while the menu is open (modal gate)")
				# -- Tab cycling (build_cycle/Q): Inventory -> Craft -> Skills -> Build (2026-10-07
				#    Milestone B inserted the recipe book and skills after the inventory) --
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_CRAFT,
					"Q cycles Inventory -> Craft")
				_check(menu_screen._craft_tab.visible and not menu_screen.inventory_tab.visible,
					"only the Craft tab's content is showing")
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_SKILLS,
					"Q cycles Craft -> Skills")
				_check(menu_screen._skills_tab.visible, "the Skills tab is showing")
				_check(menu_screen._skills_rows.get_child_count() == 5, "one row per skill")
				# Milestone B (2026-10-08): JOURNAL and PEOPLE sit between Skills and Build.
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_JOURNAL, "Q cycles Skills -> Journal")
				_check(menu_screen._journal_tab.visible and menu_screen._journal_tab.get_child_count() > 0,
					"the Journal tab is showing and filled in")
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_PEOPLE, "Q cycles Journal -> People")
				_check(menu_screen._people_tab.visible and menu_screen._people_tab.get_child_count() > 0,
					"the People tab is showing and filled in")
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_BUILD,
					"Q cycles People -> Build")
				_check(menu_screen.build_tab.visible and not menu_screen.inventory_tab.visible,
					"only the Build tab's content is showing")
				# Phase 8 Stage 1 grew the catalog to the full 12-building library; Stage 2's 4
				# fence/gate entries grew it again to 16.
				_check(menu_screen._build_row_labels.size() == 18,
					"one Build row per catalog entry (18)")
				_check(menu_screen._build_row_labels[0].text
						== "Shelter Cabin — 6 Wood  — missing materials",
					"cabin row: builder.gd's exact cost string + the missing-materials flag " \
						+ "(0 wood after the tent build), got '%s'" \
						% menu_screen._build_row_labels[0].text)
				_check(menu_screen._build_row_labels[1].text
						== "Storage Barn — 12 Wood, 4 Stone, 2 Scrap Metal  — missing materials",
					"barn row: exact cost string + missing-materials flag, got '%s'" \
						% menu_screen._build_row_labels[1].text)
				# -- Build -> Assignments -> Controls --
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_ASSIGNMENTS,
					"Q cycles Build -> Assignments")
				_check(menu_screen.assignments_tab.visible and not menu_screen.build_tab.visible,
					"only the Assignments tab's content is showing")
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_CONTROLS,
					"Q cycles Assignments -> Controls")
				_check(menu_screen.controls_rows.get_child_count()
						== menu_screen.CONTROLS_REFERENCE.size(),
					"Controls tab rendered one row per reference entry")
				# -- Controls wraps back to Inventory --
				_drive_menu_action("build_cycle")
				_check(menu_screen.tab_index == menu_screen.TAB_INVENTORY,
					"Q wraps Controls -> Inventory")
				# -- Save & Return footer: first Space arms, a tab cycle disarms --
				_check(not menu_screen._quit_armed, "quit footer starts disarmed")
				_drive_menu_action("use_tool")
				_check(menu_screen._quit_armed, "first Space arms the Save & Return confirm")
				_check(menu_screen.get_node("%QuitLabel").text.find("AGAIN") != -1,
					"the armed footer reads as a press-again confirm")
				_drive_menu_action("build_cycle")
				_check(not menu_screen._quit_armed, "cycling tabs disarms the pending quit")
				# -- Esc closes (per every other modal's convention) --
				_drive_menu_action("ui_cancel")
				_check(not menu_screen.active, "Esc closes the menu")
				_check(not menu_screen.get_node("%Box").visible, "the menu panel hid again")
				_enter_stage(101)
		101:
			# -- Menu part 2: the clock resumes, build mode works again after closing, and the
			#    reverse exclusion holds (menu refused while build mode is active) --
			if ticks < 3:  # a frame so main.gd's per-frame poll re-derived time_paused
				return false
			if ticks == 3:
				_check(not day_manager.time_paused, "closing the menu unpauses the clock")
				_drive_builder_action("build_toggle")
				_check(builder.active,
					"build mode engages normally again once the menu is closed")
				_drive_menu_action("toggle_inventory")
				_check(not menu_screen.active,
					"the menu is REFUSED while build mode is active (reverse exclusion)")
				_drive_builder_action("build_toggle")
				_check(not builder.active, "left build mode")
				# Tab both opens AND closes it (the same key toggles, like the old grid did).
				_drive_menu_action("toggle_inventory")
				_check(menu_screen.active, "Tab re-opens the menu once nothing else is open")
				_drive_menu_action("toggle_inventory")
				_check(not menu_screen.active, "Tab closes the open menu again")
				_enter_stage(70)
		70:
			# -- Phase 5 Stage 3: load the stage-15 harvested potato into the shipping box via
			#    the real facing+use_tool dispatch. Forest Edge's box is at (17,4), between the
			#    chest and the bed; the player stands on the spawn cell (17,5) directly south. --
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(Vector2i(17, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				_check(structures.is_shipping_box_at(Vector2i(17, 4)),
					"shipping box is at its authored cell")
				_check(not shipping_ui.active, "shipping UI starts closed")
				var energy_before: float = player.energy
				player.use_tool()  # the real box interaction path (player.gd's dispatch)
				_check(shipping_ui.active, "interacting with the box opened the loading UI")
				_check(player.energy == energy_before,
					"shipping-box interaction costs no energy (like chest/bed)")
				_check(not player.using_tool, "opening the box doesn't lock a tool-swing animation")
				_check(shipping_ui._index == 0, "loading UI opens on the first crop row")
				_enter_stage(71)
		71:
			# -- Drive the loading UI's real _unhandled_input (2026-10-07: rows are the shippable
			#    items being carried, and confirming loads the whole carried amount). Load the
			#    radish, prove tools/seeds are refused, then Leave — no sale until morning. --
			if ticks >= 2:
				_check(shipping_ui._row_ids.has("rain_radish") and shipping_ui._row_ids.back() == "",
					"rows list the carried radish plus a trailing Leave")
				_check(player.inventory.count_of("rain_radish") == 1,
					"the stage-15 harvested radish is still in inventory")
				var radish_row: int = shipping_ui._row_ids.find("rain_radish")
				for i in radish_row:
					_drive_shipping_action("move_down")
				_check(shipping_ui._index == radish_row, "cycled to the radish row")
				_drive_shipping_action("use_tool")
				_check(player.inventory.count_of("rain_radish") == 0,
					"loading moved the radish OUT of the inventory")
				_check(structures.shipping_contents == {"rain_radish": 1},
					"and INTO the box's pending contents")
				_check(shipping_ui.get_node("%ValueLabel").text == "In box: 30 Cr",
					"pending value readout shows the radish's 30 Cr")
				_check(not shipping_ui._row_ids.has("rain_radish"),
					"a fully loaded item leaves the row list")
				_check(not structures.add_to_shipping_box("hoe", 1),
					"the box refuses tools outright")
				_check(not structures.add_to_shipping_box("seed_mutant_potato", 1),
					"the box refuses seeds outright (can't ship away what you need)")
				var leave_row: int = shipping_ui._row_ids.size() - 1
				shipping_ui._index = 0
				for i in leave_row:
					_drive_shipping_action("move_down")
				_check(shipping_ui._index == leave_row, "cycled down to the trailing Leave row")
				_drive_shipping_action("use_tool")
				_check(not shipping_ui.active, "confirming Leave closes the loading UI")
				_check(not player.using_tool, "closing the box leaves no stray tool-swing lock")
				_check(structures.sale_history.is_empty(),
					"no sale yet — the box sells overnight (next day_started), not on close")
				_enter_stage(20)
		20:
			# -- Phase 4 Stage 3: sleep in the farmhouse bed -> auto-save (see class doc) --
			if ticks == 1:  # exactly once (ticks starts at 1 — see stage 24's note): these
				# mutations are NOT idempotent, unlike other stages' position-only setup.
				# Seed extra distinctive state for the round trip: replant + water the
				# farming-test plot (sleeping will advance it to stage 1/unwatered — that
				# advanced state is what must survive the reload), and drop items into BOTH
				# storage inventories (layout chest + built shed) so their contents round-trip.
				farm.plant(FARM_TEST_CELL, "rain_radish")
				farm.water(FARM_TEST_CELL)
				player.inventory.remove_item("seed_rain_radish", 1)  # match a real replant's cost
				structures.chest_inventory.add_item("stone", 2)
				structures.storage_inventory_at(SHED_CELL).add_item("wood", 1)
				player.set_energy(42.0)
				# Phase 5 Stage 2: Credits must round-trip too — set a fresh, distinctive value
				# here (independent of whatever balance the store stages above left behind).
				# Phase 5 Stage 3: set BEFORE sleeping on purpose — the box loaded in stage 71
				# sells overnight, so the post-sleep balance must be exactly 37 + 20.
				player.set_credits(37)
				# Stand one cell south of Forest Edge's bed at (18,4), facing it.
				player.global_position = test_map.get_global_cell_center(Vector2i(18, 5))
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
				# -- Phase 5 Stage 3: the overnight sale resolved during that same sleep, and
				#    (critically) BEFORE its auto-save — "Credits added next morning" exactly. --
				_check(player.credits == 67,
					"the sale credited exactly the radish's value (37 + 30 = 67, got %d)" \
						% player.credits)
				_check(hud.get_node("%CreditsLabel").text == "67 Cr",
					"HUD credits plaque shows the credited balance")
				_check(structures.shipping_contents.is_empty(), "the sale emptied the box")
				_check(structures.sale_history.size() == 1, "one sale-history entry recorded")
				if structures.sale_history.size() == 1:
					var sale: Dictionary = structures.sale_history[0]
					_check(int(sale["day"]) == day_manager.day,
						"history entry records the morning the Credits landed")
					_check(sale["items"] == {"rain_radish": 1},
						"history entry itemizes the sold crop")
					_check(int(sale["total"]) == 30, "history entry records the 30 Cr total")
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
			title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
			root.add_child(title)
			current_scene = title
			_enter_stage(22)
		22:
			# -- The fresh boot lands on the title screen; resuming is the explicit Load flow
			#    now (2026-07-11 multi-slot), so drive it through the REAL menu input path --
			if ticks < 10:
				return false
			_check(title.mode == title.Mode.MENU, "fresh boot shows the title menu")
			_check(title._menu_entries == ["New Game", "Load Game", "Exit"],
				"the bed save's slot makes Load Game appear on the menu (got %s)" \
					% str(title._menu_entries))
			_drive_title_action("move_down")  # New Game -> Load Game
			_check(title._menu_index == 1, "cycled to Load Game")
			_drive_title_action("use_tool")
			_check(title.mode == title.Mode.LOAD, "Load panel opened")
			_check(title._slots.size() == 1,
				"exactly the one bed-save slot is listed (got %d)" % title._slots.size())
			if title._slots.size() == 1:
				_check(int(title._slots[0]["slot_id"]) == 1, "listed slot is slot 1")
				_check(String(title._slots[0]["settlement_id"]) == "forest_edge",
					"listed slot names the saved settlement")
				_check(int(title._slots[0]["day"]) == saved_day,
					"listed slot shows the saved day (%d)" % saved_day)
			_drive_title_action("use_tool")  # confirm the slot -> load + boot main.tscn
			_enter_stage(26)
		26:
			# NOTE: 26, not 25 — stage 24 below (pre-existing, the OTHER_LAYOUT_CHECKS loop)
			# already ends its own iteration with `_enter_stage(25)`, and GDScript's `match`
			# resolves duplicate literal arms to whichever appears FIRST in source order. An
			# earlier version of this stage was numbered 25 and silently stole every one of
			# stage 24's end-of-loop transitions: the back half of this whole test (stages
			# 23/80/81/82/83/84) re-ran a second time, eventually driving
			# `_other_layout_index` past OTHER_LAYOUT_CHECKS' bounds and crashing every frame
			# forever (an infinite, near-zero-CPU "hang" — see git history for the incident).
			# Stage numbers in this file are NOT auto-checked for uniqueness — grep
			# `^\s*[0-9]+:\s*$` for the existing set before ever reusing one.
			if ticks < 20:  # let the load's change_scene_to_file complete
				return false
			main = current_scene
			_check(main != null and main.name == "Main",
				"confirming the listed slot booted main.tscn")
			if main == null or main.name != "Main":
				_finish()
				return true
			player = main.get_node("Player")
			test_map = main.zones["farm"]["map"]
			farm = main.zones["farm"]["farm"]
			structures = main.zones["farm"]["structures"]
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
			_check(hud.get_node("%DayLabel").text == Calendar.date_text(saved_day), "HUD shows the loaded day")
			_check(player.global_position == saved_position,
				"player position restored (%s, expected %s)" % [player.global_position, saved_position])
			_check(player.facing == "north", "player facing restored")
			_check(player.energy == player.max_energy, "energy restored (full — saved after waking)")
			_check(hud.get_node("%EnergyFill").value == player.max_energy, "HUD energy bar restored")
			_check(player.credits == 67,
				"Credits balance restored INCLUDING the sale credit (%d, expected 67)" % player.credits)
			_check(hud.get_node("%CreditsLabel").text == "67 Cr", "HUD credits label restored")
			# Inventory: exact contents from the played-through session, not the starting loadout
			# + settlement bonus a fresh game would have granted.
			_check(player.inventory.get_slot(0).get("item_id", "") == "hoe", "hoe back in slot 1")
			_check(int(player.inventory.get_slot(0).get("tier", -1)) == 1,
				"hoe tier survived the round trip")
			_check(player.inventory.count_of("wood") == 0, "wood count (all spent building) restored")
			_check(player.inventory.count_of("rain_radish") == 0,
				"the shipped radish stays gone from the inventory after reload")
			_check(player.inventory.count_of("seed_rain_radish") == 14,
				"seed count (15 - planted 2 + 1 bought from Marta's store) restored")
			_check(player.inventory.selected_hotbar_index == 2,
				"hotbar selection (axe, from the chop) restored")
			# World modifications:
			_check(test_map.is_tilled_at(FARM_TEST_CELL), "player-tilled cell restored")
			var plot: Dictionary = farm.get_plot(FARM_TEST_CELL)
			_check(plot.get("crop_id", "") == "rain_radish", "planted crop restored")
			_check(int(plot.get("stage", -1)) == 1,
				"crop stage restored at 1 (watered plot advanced by the sleep's day tick)")
			_check(not bool(plot.get("watered", true)), "watered flag consumed by the day tick")
			var objects_reloaded: Node = test_map.get_node("Objects")
			_check(String(objects_reloaded.kind_at(Vector2i(33, 2))).begins_with("stump"),
				"the felled tree's stump (not the tree) is what reloads")
			_check(String(objects_reloaded.kind_at(Vector2i(20, 1))).begins_with("tree"),
				"an unchopped tree is still standing")
			# Player-built structures + storage:
			_check(structures._pending.is_empty() and structures._completed.size() == 4,
				"all 4 completed structures restored (shed, tent, fence, gate)")
			_check(structures.is_chest_at(SHED_CELL) and structures.is_chest_at(SHED_CELL_SE),
				"restored shed is storage on its footprint")
			_check(structures.storage_inventory_at(SHED_CELL) != null and
				structures.storage_inventory_at(SHED_CELL).count_of("wood") == 1,
				"shed storage contents restored")
			_check(structures.chest_inventory.count_of("stone") == 2, "layout chest contents restored")
			_check(not structures.is_chest_at(TENT_CELL), "restored tent is not storage")
			# The _runtime_blocked overlay was re-derived from the restored structures, not
			# serialised (see save_data.gd's class doc):
			_check(test_map.is_blocked_at(SHED_CELL) and test_map.is_blocked_at(TENT_CELL),
				"restored footprints re-registered as blocked")
			_check(not farm.can_till(Vector2i(31, 9)), "can't till under the restored shed")
			# Phase 8 Stage 2: solidity survives the round trip too (_restore_entry re-derives it
			# from BuildingDB.solid(), never serialised) — the completed Fence is still blocked,
			# the completed Gate is still walkable, and the occupied-footprint guard still holds.
			_check(test_map.is_blocked_at(FENCE_CELL), "restored fence stays blocked")
			_check(not test_map.is_blocked_at(GATE_CELL), "restored gate stays walkable")
			_check(not structures.can_place(GATE_CELL, Vector2i.ONE),
				"restored gate still refuses a second building on top of it")
			_check(not structures.can_place(FENCE_CELL, Vector2i.ONE),
				"restored fence still refuses a second building on top of it")
			_check(structures.is_bed_at(Vector2i(18, 4)), "bed present again after reload")
			# -- Phase 5 Stage 3: the sold-and-emptied box and its sale history survived too --
			_check(structures.is_shipping_box_at(Vector2i(17, 4)),
				"shipping box present again after reload")
			_check(structures.shipping_contents.is_empty(),
				"reloaded box is empty (its load was sold before the save)")
			_check(structures.sale_history.size() == 1, "sale history restored from the save")
			if structures.sale_history.size() == 1:
				var sale: Dictionary = structures.sale_history[0]
				_check(int(sale["day"]) == saved_day and sale["items"] == {"rain_radish": 1} \
						and int(sale["total"]) == 30,
					"restored history entry matches the recorded sale (got %s)" % str(sale))
			# Test hygiene (hard requirement): remove the test save so repeated runs start clean.
			# (Stage 81 below writes a fresh one for the pending-box round trip.)
			game_state.delete_save()
			_check(not game_state.has_save(), "test save file cleaned up")
			_enter_stage(80)
		80:
			# -- Phase 5 Stage 3 capstone: spend the sale-earned (and reloaded) Credits at
			#    Marta's store, through the real dialogue-choice path — the phase milestone's
			#    "farm, sell crops, earn currency, and buy seeds" chain closed in one run. --
			if ticks < 5:
				# Re-fetch the UI nodes stage 22's reload rebuilt (it only re-fetched the world
				# nodes the stage-23 checks needed), then walk over to town — Marta's store is
				# Town-zone content since the split.
				dialogue_ui = main.get_node("DialogueUI")
				store_ui = main.get_node("StoreUI")
				shipping_ui = main.get_node("ShippingUI")
				_warp_to("town")
				var npc: Node = _npc_by_id("marta")
				var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, -1))
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active, "Marta's dialogue still opens after the reload")
				_drive_dialogue_action("use_tool")  # reveal greet
				_drive_dialogue_action("use_tool")  # advance greet -> stocktake
				_drive_dialogue_action("use_tool")  # reveal stocktake's branch prompt
				_drive_dialogue_action("use_tool")  # confirm "Let's see what you've got"
				_check(store_ui.active, "the store opened via the real dialogue choice")
				_check(player.credits == 67,
					"walking in with exactly the sale-earned balance (67, got %d)" % player.credits)
				var seeds_before: int = player.inventory.count_of("seed_rain_radish")
				_drive_store_action("use_tool")  # buy row 0: seed_rain_radish, 12 Cr
				_check(player.credits == 55,
					"bought seeds WITH the shipping-box Credits (67 -> 55, got %d)" % player.credits)
				_check(player.inventory.count_of("seed_rain_radish") == seeds_before + 1,
					"the purchased seed landed in inventory — the economy loop is closed")
				_drive_store_action("move_up")  # row 0 wraps straight up to the trailing Leave row
				_check(store_ui._index == store_ui._row_ids.size() - 1 and store_ui._row_ids[store_ui._index] == "",
					"move_up wraps to the trailing Leave row")
				_drive_store_action("use_tool")
				_check(not store_ui.active, "left the store cleanly")
				_enter_stage(81)
		81:
			# -- The other Stage 3 save-shape requirement: a box loaded but NOT slept through
			#    must survive a save/reload with its pending contents intact. --
			if ticks == 1:  # exactly once: add_item is not idempotent (see stage 20's note)
				# Seed 2 sunbloom to ship (same seed-distinctive-state convention as stage 20 —
				# growing a second crop through stages 10-15 again would re-prove farming, not
				# shipping), head home (the box is farm-zone content — and saving farm-bound is
				# what the reload below must restore), and stand at the box.
				player.inventory.add_item("sunbloom", 2)
				_warp_to("farm")
				player.global_position = test_map.get_global_cell_center(Vector2i(17, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks < 5:
				return false
			if ticks == 5:
				player.use_tool()
				_check(shipping_ui.active, "the loading UI opens after the reload too")
				var sun_row: int = shipping_ui._row_ids.find("sunbloom")
				for i in sun_row:
					_drive_shipping_action("move_down")
				_check(shipping_ui._index == sun_row, "cycled to the sunbloom row")
				_drive_shipping_action("use_tool")  # loads the whole stack: both
				_check(player.inventory.count_of("sunbloom") == 0, "both sunbloom left the inventory")
				_check(structures.shipping_contents == {"sunbloom": 2},
					"box holds the pending 2-sunbloom load")
				shipping_ui._index = shipping_ui._row_ids.size() - 2
				_drive_shipping_action("move_down")  # -> Leave
				_drive_shipping_action("use_tool")
				_check(not shipping_ui.active, "left the loading UI")
				# Mid-session save through the SAME GameState call the bed makes — called
				# directly, because the bed path would sell the load first, which is exactly
				# the state this round trip must preserve un-sold. Zone-split signature: the
				# whole zones dict, not one map's node trio.
				_check(game_state.save_game(player, main.zones, main.get_node("Settlers"), main.get_node("Animals"), main.get_node("Affinity")),
					"mid-session save written with the box still loaded")
				saved_day = day_manager.day
				_enter_stage(82)
		82:
			# -- Second teardown/reboot, same shape as stage 21 --
			if ticks < 5:
				return false
			main.queue_free()
			main = null
			game_state.chosen_settlement_id = "open_plains"
			day_manager.day = 1
			day_manager.minutes_into_day = 400.0
			title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
			root.add_child(title)
			current_scene = title
			_enter_stage(83)
		83:
			# Same real title -> Load -> slot drive as stage 22 (lighter checks — the listing
			# itself was verified there; this run is about the pending-box save's content).
			if ticks < 10:
				return false
			_drive_title_action("move_down")
			_drive_title_action("use_tool")
			_check(title.mode == title.Mode.LOAD, "Load panel opened for the pending-box save")
			_check(title._slots.size() == 1 and int(title._slots[0]["day"]) == saved_day,
				"the mid-session save's slot is listed with its day")
			_drive_title_action("use_tool")
			_enter_stage(85)
		85:
			if ticks < 20:  # let the load's change_scene_to_file complete
				return false
			main = current_scene
			_check(main != null and main.name == "Main",
				"loading the slot booted main.tscn again for the pending-box save")
			if main == null or main.name != "Main":
				_finish()
				return true
			player = main.get_node("Player")
			test_map = main.zones["farm"]["map"]
			farm = main.zones["farm"]["farm"]
			structures = main.zones["farm"]["structures"]
			hud = main.get_node("HUD")
			_enter_stage(84)
		84:
			# -- Pending contents survived un-sold; and the reloaded load still sells correctly
			#    on the next real bed sleep --
			if ticks < 10:
				return false
			if ticks == 10:
				_check(day_manager.day == saved_day, "day restored for the pending-box save")
				_check(structures.shipping_contents == {"sunbloom": 2},
					"a loaded-but-not-slept box survives the reload intact (got %s)" \
						% str(structures.shipping_contents))
				_check(structures.sale_history.size() == 1,
					"history still holds exactly the one earlier sale (no phantom sale on load)")
				_check(player.credits == 55, "credits restored un-credited (55, got %d)" % player.credits)
				player.global_position = test_map.get_global_cell_center(Vector2i(18, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"  # targets (18,4), the bed
				return false
			if ticks == 15:
				var day_before: int = day_manager.day
				player.use_tool()  # sleep: the reloaded pending load must sell now
				_check(day_manager.day == day_before + 1, "sleeping advanced the day")
				_check(player.credits == 355,
					"the reloaded load sold for exactly 2 x 150 Cr (55 + 300 = 355, got %d)" \
						% player.credits)
				_check(structures.shipping_contents.is_empty(), "box emptied by the post-reload sale")
				_check(structures.sale_history.size() == 2, "second sale-history entry appended")
				if structures.sale_history.size() == 2:
					var sale: Dictionary = structures.sale_history[1]
					_check(int(sale["day"]) == day_manager.day and sale["items"] == {"sunbloom": 2} \
							and int(sale["total"]) == 300,
						"second entry itemizes the sunbloom sale (got %s)" % str(sale))
				# Final test hygiene: the sleep re-saved; wipe the whole test saves dir so
				# repeated runs start clean.
				_delete_test_saves()
				_check(not game_state.has_save(), "test save file cleaned up (final)")
				_check(game_state.list_slots().is_empty(), "no test slots left behind (final)")
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
			# Painted == authored, derived from the layout's own data (see OTHER_LAYOUT_CHECKS'
			# doc — a standalone test_map.tscn is that settlement's FARM zone since the split).
			var layout_size: Vector2i = check["layout"].size()
			var other_stats: Dictionary = _other_layout_map.render_stats()
			_check(int(other_stats["base"]) == layout_size.x * layout_size.y,
				"%s grass base fully painted (%dx%d)" % [id, layout_size.x, layout_size.y])
			var expected_solid := 0
			for row in check["layout"].ROWS:
				for ch in ["#", "F", "W"]:
					expected_solid += String(row).count(ch)
			_check(int(other_stats["wall_cells"]) == expected_solid,
				"%s collision covers its authored solid cells" % id)
			_check(int(other_stats["fences"]) == check["layout"].fence_cells().size(),
				"%s fence sprites match its authored 'F' cells" % id)
			_check((int(other_stats["water"]) > 0) == (check["layout"].water_cells().size() > 0),
				"%s water layer painted iff it authors water" % id)
			_check(int(other_stats["planks"]) + int(other_stats["road"])
					== check["layout"].dock_cells().size(),
				"%s decking + road match its authored 'p' cells" % id)
			_check(_other_layout_map.get_node("Structures").get_child_count()
					== check["layout"].buildings().size(),
				"%s spawned all %d buildings" % [id, check["layout"].buildings().size()])
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
		GATE_WALK_STAGE:
			# -- Zone-transition Stage 3: one REAL gate-cell crossing per remaining hop of
			#    _gate_route (see GATE_WALK_STAGE's doc). Standing the player on the authored
			#    gate cell lets player.gd's own _physics_process detection fire
			#    zone_exit_requested → main._on_zone_exit_requested → zone_fade.play →
			#    _bind_zone — the genuine crossing path, asserted to fire EXACTLY once per
			#    hop via the signal counter connected in stage 1. --
			if _gate_route.is_empty():
				_rebind_zone_refs(player.current_zone_id)
				_enter_stage(_gate_next_stage)
				return false
			var hop: Array = _gate_route[0]
			if ticks < 2:
				return false  # settle a frame between hops
			if ticks == 2:
				_check(player.current_zone_id == String(hop[0]),
					"gate walk: hop starts in %s (got %s)" % [hop[0], player.current_zone_id])
				_gate_signals_before = _gate_exit_signals
				player.velocity = Vector2.ZERO
				player.global_position = \
					main.zones[String(hop[0])]["map"].get_global_cell_center(Vector2i(hop[1]))
				return false
			# Wait out the full warp (detection frame + ~0.15s fade), then verify the real
			# signal fired once and the arrival state is coherent.
			if player.current_zone_id == String(hop[2]) \
					and not main.zone_fade.playing and ticks > 12:
				_check(_gate_exit_signals == _gate_signals_before + 1,
					"gate walk %s→%s: zone_exit_requested fired exactly once (saw %d)"
						% [hop[0], hop[2], _gate_exit_signals - _gate_signals_before])
				_check(main.zone_fade.rejected_count == 0,
					"gate walk %s→%s: zone_fade never re-entered mid-tween" % [hop[0], hop[2]])
				_check(player.test_map == main.zones[String(hop[2])]["map"],
					"gate walk %s→%s: player rebound to the arrival zone's map" % [hop[0], hop[2]])
				_gate_route.remove_at(0)
				_enter_stage(GATE_WALK_STAGE)  # next hop (or the handoff branch above)
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


## Same idea, for the title screen's real _unhandled_input (2026-07-11 multi-slot title/Load
## flow, stages 40/22/83) — menu and Load-panel navigation both route through it.
func _drive_title_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	title._unhandled_input(event)


## Wipes the test-only saves directory (every file, then the directory itself) — the
## multi-slot analogue of the old single-file delete_save() hygiene. Safe on a missing dir.
func _delete_test_saves() -> void:
	var abs_dir := ProjectSettings.globalize_path(String(game_state.saves_dir))
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file_name in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file_name))
	DirAccess.remove_absolute(abs_dir)


## Same idea again, for store_ui.gd's real _unhandled_input (Phase 5 Stage 2) — drives
## "use_tool"/"move_up"/"move_down" through the actual handler rather than calling its private
## _confirm()/etc. methods directly.
func _drive_store_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	store_ui._unhandled_input(event)


## Same idea once more, for menu_screen.gd's real _unhandled_input (2026-07-12 in-game tabbed
## menu, stages 100-101) — drives "toggle_inventory"/"build_cycle"/"use_tool"/"ui_cancel"
## through the actual handler rather than calling open_menu()/close() directly.
func _drive_menu_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	menu_screen._unhandled_input(event)


## Same idea once more, for shipping_ui.gd's real _unhandled_input (Phase 5 Stage 3) — drives
## "use_tool"/"move_up"/"move_down" through the actual handler rather than calling its private
## _confirm()/etc. methods directly.
func _drive_shipping_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	shipping_ui._unhandled_input(event)


## Re-points this smoke's world refs at `zone_id`'s nodes (no player repositioning) — shared by
## both warp paths below.
func _rebind_zone_refs(zone_id: String) -> void:
	test_map = main.zones[zone_id]["map"]
	farm = main.zones[zone_id]["farm"]
	structures = main.zones[zone_id]["structures"]
	npcs = main.zones[zone_id]["npcs"]


## Rebinds the player into `zone_id` through main.gd's real _bind_zone (the same rebind a gate
## crossing performs, minus the fade) and re-points this smoke's world refs at that zone's
## nodes. Needed since the zone split: the town core, its NPCs/store, and the ranch each live
## in their own sibling zone. The first town round trip goes through _begin_gate_walk below
## instead (the REAL gate-cell path); later stages use this direct shortcut once that's covered.
func _warp_to(zone_id: String) -> void:
	main._bind_zone(zone_id)
	_rebind_zone_refs(zone_id)


## Kicks off a real gate-cell walk (see GATE_WALK_STAGE's doc): queues `route`'s hops for the
## stage-200 sub-machine, which enters `next_stage` after the last arrival, world refs rebound.
func _begin_gate_walk(route: Array, next_stage: int) -> void:
	_gate_route = route.duplicate()
	_gate_next_stage = next_stage
	_enter_stage(GATE_WALK_STAGE)


## Looks up a spawned NPC by its dialogue/roster id (scripts/npcs.gd's spawn list) — in the
## currently-bound zone's roster by default, or an explicit zone's (the zone split moved every
## NPC out of the farm zone, so farm-bound stages pass zone_id explicitly).
func _npc_by_id(id: String, zone_id: String = "") -> Node:
	var roster: Node = npcs if zone_id == "" else main.zones[zone_id]["npcs"]
	for npc in roster.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


## Something other than _finish ended the run (2026-10-08: a cascade of failed checks walked the
## rebuilt title screen onto Exit, which quits with 0) — say so, and list what had failed, rather
## than ending silently with a clean exit code.
func _finalize() -> void:
	if _finished:
		return
	print("RUNTIME SMOKE FAIL: the run ended at stage %d before finishing" % stage)
	for failure in failures:
		print("RUNTIME SMOKE FAIL: %s" % failure)


var _finished := false


func _finish() -> void:
	_finished = true
	if failures.is_empty():
		print("RUNTIME SMOKE: all checks passed.")
		quit(0)
	else:
		for failure in failures:
			print("RUNTIME SMOKE FAIL: %s" % failure)
		quit(1)
