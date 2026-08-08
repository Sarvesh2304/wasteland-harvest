extends SceneTree
## Headless 5-day stability soak test (ROADMAP.md Phase 6: "Bug-fixing sprint — play through 5
## in-game days end to end" + "All Year 1 systems integrated ... without conflicts").
##
## ## Why a separate file from tools/runtime_smoke.gd
## The smoke test is a FEATURE test: each phase spliced in its own isolated stages, verifying
## each mechanism's contract one at a time (and it has grown to ~1300 lines doing so). This file
## is a SOAK test: one continuous, realistic multi-day playthrough where several systems are
## genuinely live at once — crops growing across plots while buildings pend construction while
## the shipping box holds a load while saves land mid-stream — hunting cross-system conflicts
## that per-feature isolation structurally cannot catch. Extending the smoke test with this
## would have doubled an already-unwieldy file while muddying both jobs; a dedicated tool keeps
## each runnable (and readable) on its own.
##
## Run: godot --headless --path . --script res://tools/soak_test.gd
##
## ## The playthrough (Forest Edge, chosen for its buildable-materials starting bonus)
##   Day 1: till/plant/water 3 mutant-potato plots through the real player.use_tool() dispatch;
##          full conversation with Scout Kael — DURING which the Phase 6 modal-conflict fix is
##          exercised (a "B" press through builder.gd's real input handler must refuse to engage
##          build mode mid-dialogue, and a shared "use_tool" press delivered to both nodes must
##          advance the dialogue while placing NOTHING); the HUD's "I" inventory-grid toggle is
##          also flipped mid-dialogue (it's a passive overlay, deliberately NOT modal — it must
##          keep working without breaking the conversation); then a Storage Shed blueprint is
##          placed through the real build-mode input path — during which the REVERSE exclusion
##          is checked (dialogue/shipping open attempts refused while build mode is active) —
##          and the day ends with a real bed sleep (auto-save #1).
##   Day 2: water everything, chop a tree, then stay up ALL NIGHT via 1-minute advance_minutes()
##          ticks (the same API DayManager._process drives with frame deltas — a legitimate
##          acceleration of the real path, not a test-only fork; every other day ends through
##          the bed path, so both day-rollover routes get soaked). Crossing midnight exercises
##          the natural rollover; staying up past it exercises the 2026-07-11 night rules end
##          to end — sleepy HUD cue, exact passive-drain arithmetic, and the 2 AM forced
##          pass-out with its auto-save and its no-double-growth/no-skipped-day guarantees.
##   Day 3: water, full conversation with Mayor Harlan, then a MID-SESSION save + full teardown/
##          reboot through the real resume path — with crops mid-growth, a completed player
##          building standing, and the save file's JSON re-parsed to prove it isn't corrupt.
##   Day 4: water, sleep.
##   Day 5: harvest 2 of the 3 mature potatoes (the third stays standing), place a Shelter Tent
##          blueprint, load both potatoes into the shipping box, sleep -> the day-6 morning tick
##          resolves CONSTRUCTION COMPLETION and the SHIPPING SALE and the FARM GROWTH pass all
##          on the same day_started emission — the exact multi-subscriber pileup the checklist's
##          "without conflicts" is about. Credits are asserted EXACTLY (+40, no double-credit).
##   Day 6: buy 2 dustwheat seeds at Marta's store through the real dialogue-choice path (spending
##          the sale's Credits — economy loop live mid-soak), with another build-toggle refusal
##          check while the store is open; harvest the last potato; till/plant/water 2 dustwheat
##          plots (second crop type growing concurrently); ship the last potato; sleep.
##   Day 7: second morning sale resolves (+20, exact); dustwheat advanced a stage; the player
##          walks away under real held input (the "never stuck" check); final save-file hygiene.
## Day counter: 1 -> 7 = six full in-game days end to end (the checklist asks for 5).
##
## Uses a test-only saves directory (game_state.saves_dir + a slot-file save_path inside it,
## with legacy_save_path redirected too — the 2026-07-11 multi-slot analogue of the old
## test-only filename), wiped before and after (same hard requirement as runtime_smoke.gd —
## repeated runs must never inherit stale state, and a real playthrough's slots/legacy save
## must never be touched).

const CropDB := preload("res://scripts/crop_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")

## Coordinates re-anchored to the FARM ZONE's local grid after the zone split (the farm is
## 36x16 now; the old combined map's town rows 16+ live in the Town zone). Rows 9/10 and 14
## are open grass on the farm's Forest Edge ROWS, clear of the pre-baked farmland patches,
## the SW creek, treeline/salvage, and every building. The old NPC-clearance constraint is
## gone with the split — no NPC lives in the farm zone anymore (town visits warp, see
## _warp_to below).
const POTATO_CELLS: Array[Vector2i] = [Vector2i(5, 14), Vector2i(6, 14), Vector2i(7, 14)]
const DUSTWHEAT_CELLS: Array[Vector2i] = [Vector2i(9, 14), Vector2i(10, 14)]
const SHED_STAND := Vector2i(30, 8)   # facing south -> 2x2 shed lands at (30,9)-(31,10)
const SHED_CELL := Vector2i(30, 9)    # the shed footprint's top-left (storage checks)
const TENT_STAND := Vector2i(24, 13)  # facing south -> 1x1 tent lands at (24,14)
const TREE_CELL := Vector2i(33, 2)    # authored treeline 'T', stand (32,2) facing east
const BED_STAND := Vector2i(18, 5)    # facing north -> bed at (18,4)
const BOX_STAND := Vector2i(17, 5)    # facing north -> shipping box at (17,4)

## Zone-transition plan, Stage 3: the day-1 town round trip (stages 2/3) crosses through the
## REAL gate-cell path — the player is stood on the authored gate cell and player.gd's own
## _physics_process detection fires zone_exit_requested → main's fade → _bind_zone, the genuine
## crossing code path — one hop per seam, each direction (farm→path→town out, town→path→farm
## home), with the signal counted and asserted exactly-once per hop. The later town trips
## (stages 6/11/12) stay direct _warp_to() shortcuts by design, per the plan ("faster direct
## _bind_zone() calls are fine for the remaining stages once that's covered");
## tools/zone_transition_smoke.gd owns proving all six crossings exhaustively. Routes:
## [from_zone, its authored gate cell, expected arrival zone] — coordinates hold for every
## settlement variant (the layouts author identical gate positions).
const GATE_WALK_STAGE := 20
const ROUTE_FARM_TO_TOWN := [
	["farm", Vector2i(35, 4), "path"],
	["path", Vector2i(23, 4), "town"],
]
const ROUTE_TOWN_TO_FARM := [
	["town", Vector2i(0, 4), "path"],
	["path", Vector2i(0, 4), "farm"],
]
var _gate_route: Array = []
var _gate_next_stage := 0
## zone_exit_requested emissions observed (connected in _fetch_world_nodes).
var _gate_exit_signals := 0
var _gate_signals_before := 0

var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var farm: Node
var structures: Node
var builder: Node2D
var npcs: Node
var dialogue_ui: Node
var store_ui: Node
var shipping_ui: Node
var menu_screen: Node
var hud: CanvasLayer

var stage := 0
var stage_started_at := 0
var failures: Array[String] = []
## Snapshot for the final "player can still walk" held-input check.
var _walk_start_pos := Vector2.ZERO
## The title screen instance the day-3 reboot creates (stage 7) and drives (stage 8).
var _title: Control = null


func _initialize() -> void:
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	# Test-only saves DIRECTORY, wiped up front (see class doc / runtime_smoke.gd's identical
	# rule, extended for the 2026-07-11 multi-slot system): save_path is pinned to a slot file
	# INSIDE it so the day-3 reboot's title-screen Load list (stage 8) can find the save, and
	# legacy_save_path is redirected so the title screen's migration step can never touch a
	# real playthrough's user://savegame.json during a test run.
	game_state.saves_dir = "user://soak_test_saves"
	game_state.legacy_save_path = "user://soak_test_saves/legacy.json"
	game_state.save_path = "user://soak_test_saves/slot_1.json"
	_delete_test_saves()
	# Direct main.tscn boot with a pinned settlement: the picker's own flow is runtime_smoke.gd's
	# job; the soak needs Forest Edge specifically (its starting bonus affords the day-1 shed).
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("stage %d: %s" % [stage, message])


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


## Watchdog (2026-07-11, ported from the same fix in tools/runtime_smoke.gd after a real
## incident there — a duplicate match-arm stage number hijacked a transition and the run
## looped silently for 12+ minutes at near-zero CPU before being caught by hand). Comfortably
## above the longest legitimate in-stage tick wait in this file (90) so it never fires on a
## healthy run, but guarantees a future stall fails LOUDLY with the exact stuck stage.
const MAX_TICKS_PER_STAGE := 1800
var _watchdog_tripped := false


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		push_error("soak_test watchdog: stuck in stage %d for %d ticks" % [stage, ticks])
		_check(false, "TIMED OUT after %d ticks with no stage transition (watchdog)" % ticks)
		_finish()
		return true
	match stage:
		0:
			# -- Boot: world up, gate wired, Forest Edge bonus granted --
			if ticks < 10:
				return false
			_fetch_world_nodes()
			_check(day_manager.day == 1, "soak starts on day 1")
			_check(player.inventory.count_of("seed_mutant_potato") == 5, "5 starting potato seeds")
			_check(player.inventory.count_of("wood") == 15, "Forest Edge bonus wood granted")
			_check(main.modal_gate != null, "main.gd owns a modal gate")
			for surface in [builder, dialogue_ui, store_ui, shipping_ui, menu_screen]:
				_check(surface.modal_gate == main.modal_gate,
					"%s is wired to the shared modal gate" % surface.name)
			_enter_stage(1)
		1:
			# -- Day 1: till/plant/water all 3 potato plots via the real use_tool dispatch --
			if ticks < 5:
				return false
			for cell in POTATO_CELLS:
				_use_on_cell(cell, 0)  # hoe: till
				_use_on_cell(cell, 5)  # slot 6 = starting potato seeds: plant
				_use_on_cell(cell, 1)  # watering can: water
			for cell in POTATO_CELLS:
				_check(test_map.is_tilled_at(cell), "cell %s tilled" % cell)
				var plot: Dictionary = farm.get_plot(cell)
				_check(String(plot.get("crop_id", "")) == "mutant_potato",
					"potato planted at %s" % cell)
				_check(bool(plot.get("watered", false)), "plot %s watered" % cell)
			_check(player.inventory.count_of("seed_mutant_potato") == 2,
				"3 of 5 potato seeds consumed")
			_check(player.energy == 92.5,
				"day-1 farming energy ledger holds (100 - 3x2.5 = 92.5, got %.2f)" % player.energy)
			# Head to town for Kael THROUGH the real gate-cell walk (farm→path→town) — see
			# GATE_WALK_STAGE's doc.
			_begin_gate_walk(ROUTE_FARM_TO_TOWN, 2)
		2:
			# -- Day 1: Scout Kael conversation + the modal-conflict checks (see class doc).
			#    Arrived town-bound via the real gate walk (stage 20). --
			if ticks < 5:
				var npc: Node = _npc_by_id("scout_kael")
				player.global_position = test_map.get_global_cell_center(
					test_map.world_to_cell(npc.global_position) + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active and dialogue_ui.npc == _npc_by_id("scout_kael"),
					"Kael's dialogue opened via the real interaction path")
				# THE FIXED BUG, driven through builder.gd's real input handler: "B" mid-dialogue
				# must refuse to engage build mode (before the fix it engaged silently underneath).
				_drive(builder, "build_toggle")
				_check(not builder.active,
					"build_toggle is REFUSED while a dialogue is open (the Phase 6 fix)")
				# And the double-drive that refusal prevents: the same "use_tool" press delivered
				# to both nodes (Godot gives unhandled input to every node; neither marks it
				# handled) must advance the dialogue while building NOTHING.
				var pending_before: int = structures._pending.size()
				var wood_before: int = player.inventory.count_of("wood")
				_drive(builder, "use_tool")
				_drive(dialogue_ui, "use_tool")
				_check(dialogue_ui._is_fully_revealed(),
					"the shared use_tool press advanced the dialogue (instant reveal)")
				_check(structures._pending.size() == pending_before,
					"...and placed no blueprint")
				_check(player.inventory.count_of("wood") == wood_before,
					"...and spent no resources")
				# 2026-07-12: "toggle_inventory" now opens the tabbed in-game menu
				# (scripts/menu_screen.gd), a TRUE modal — unlike the passive grid it replaced,
				# it must be REFUSED mid-dialogue, exactly like build_toggle above.
				_drive(menu_screen, "toggle_inventory")
				_check(not menu_screen.active,
					"the in-game menu is REFUSED while a dialogue is open (modal, unlike the " \
						+ "passive grid it replaced)")
				_check(dialogue_ui.active, "...and the refusal didn't disturb the dialogue")
				# Finish Kael's chain (bounded, per the smoke test's convention).
				var guard := 0
				while dialogue_ui.active and guard < 20:
					_drive(dialogue_ui, "use_tool")
					guard += 1
				_check(guard < 20 and not dialogue_ui.active, "Kael's conversation closed cleanly")
				_check(not builder.active, "build mode is still off after the conversation")
				# Home the same way: the real west gate walk (town→path→farm).
				_begin_gate_walk(ROUTE_TOWN_TO_FARM, 3)
		3:
			# -- Day 1: place the Storage Shed via the real build-mode input path, checking the
			#    REVERSE exclusion (other modals refused while build mode is active).
			#    (Arrived farm-bound via the real gate walk home, stage 20.) --
			if ticks < 5:
				player.global_position = test_map.get_global_cell_center(SHED_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				_drive(builder, "build_toggle")
				_check(builder.active, "build mode engages normally once nothing else is open")
				# Reverse direction: while build mode is active, the signal-opened UIs must
				# refuse to open (structurally unreachable through play, but the gate makes the
				# invariant explicit — prove it holds).
				shipping_ui.open_box()
				_check(not shipping_ui.active, "shipping UI refuses to open while in build mode")
				var npc: Node = _npc_by_id("marta", "town")  # farm-bound here; Marta's in town
				dialogue_ui.open_dialogue(npc)
				_check(not dialogue_ui.active, "dialogue refuses to open while in build mode")
				_check(not bool(npc.talking), "...and the NPC was never frozen by the refusal")
				_drive(builder, "build_cycle")
				_check(builder.current_id() == "storage_shed", "cycled to the Storage Shed")
				_check(builder.confirm_placement(), "shed blueprint placed")
				_check(player.inventory.count_of("wood") == 3, "shed spent 12 wood (15 -> 3)")
				_check(structures._pending.size() == 1, "shed is pending construction")
				_drive(builder, "build_toggle")
				_check(not builder.active, "left build mode")
				_enter_stage(4)
		4:
			# -- Day 1 -> 2: real bed sleep (auto-save #1); shed completes, crops advance --
			if ticks < 5:
				return false
			if ticks == 5:
				_sleep_in_bed()
				_check(day_manager.day == 2, "sleeping advanced to day 2")
				_check(player.energy == player.max_energy, "woke rested")
				_check(game_state.has_save(), "the bed auto-saved")
				_check(structures._pending.is_empty() and structures._completed.size() == 1,
					"shed construction completed on the day-2 morning")
				_check(structures.is_chest_at(SHED_CELL), "completed shed is storage")
				for cell in POTATO_CELLS:
					var plot: Dictionary = farm.get_plot(cell)
					_check(int(plot.get("stage", -1)) == 1 and not bool(plot.get("watered", true)),
						"plot %s advanced to stage 1, watered flag consumed" % cell)
				_enter_stage(5)
		5:
			# -- Day 2: water, gather wood, then stay up ALL NIGHT: cross midnight naturally via
			#    1-minute advance_minutes() ticks (the same API DayManager._process feeds with
			#    frame deltas) and run head-first into the 2026-07-11 night rules — the
			#    post-midnight sleepy drain, the HUD cue, and the 2 AM forced pass-out (with
			#    auto-save) end this night for us. Replaces the original single 1440-minute
			#    jump: that teleported clean over the [midnight, 6 AM) window in one emission
			#    (which real frame-driven play can never do), and with the night rules live the
			#    honest version of "cross midnight awake" IS a 2 AM collapse — so the soak now
			#    proves the new rules fire correctly mid-playthrough with every other system
			#    (crops mid-growth, completed shed, live save file) running alongside.
			if ticks < 5:
				return false
			if ticks == 5:
				for cell in POTATO_CELLS:
					_use_on_cell(cell, 1)
				# Chop the (33,2) treeline tree: 3 wood -> 6 total, affording day 5's tent.
				player.global_position = test_map.get_global_cell_center(TREE_CELL + Vector2i(-1, 0))
				player.velocity = Vector2.ZERO
				player.facing = "east"
				player.inventory.select_hotbar(2)  # axe
				_check(farm.can_chop(TREE_CELL), "treeline tree standing")
				player.use_tool()
				_check(player.inventory.count_of("wood") == 6, "chop granted 3 wood (3 -> 6)")
				_check(player.energy == 95.5,
					"day-2 ledger before the all-nighter (100 - 3 water - 1.5 chop = 95.5)")
				# Prove the pass-out itself writes a save: start provably save-free (the bed's
				# stage-4 save would otherwise mask it).
				game_state.delete_save()
				# 2026-08-09 HUD polish: world-space Label on the Player, resolved by hud.gd.
				var sleepy_label: Label = hud.sleepy_label
				_check(not sleepy_label.visible, "no sleepy cue during the day-2 evening")
				var guard := 0
				# Stay up to midnight: the rollover ticks growth exactly once...
				while day_manager.day < 3 and guard < 2000:
					day_manager.advance_minutes(1.0)
					guard += 1
				_check(day_manager.day == 3, "natural midnight rollover reached day 3")
				for cell in POTATO_CELLS:
					_check(int(farm.get_plot(cell).get("stage", -1)) == 2,
						"plot %s advanced to stage 2 on the natural rollover" % cell)
				_check(sleepy_label.visible, "the GETTING SLEEPY cue is up past midnight")
				# ...on to ~1 AM: the passive drain must match the lived-through minutes exactly
				# (0.15/game-minute from the moment midnight struck — nothing before it).
				while day_manager.minutes_into_day < 60.0 and guard < 2000:
					day_manager.advance_minutes(1.0)
					guard += 1
				var expected: float = 95.5 \
					- day_manager.minutes_into_day * player.SLEEPY_DRAIN_PER_GAME_MINUTE
				_check(absf(player.energy - expected) < 0.001,
					"sleepy drain integrates exactly (expected %.3f, got %.3f)"
						% [expected, player.energy])
				# ...and into the 2 AM wall: the forced pass-out ends the night regardless of
				# the ~77 energy still in the bar.
				while day_manager.day == 3 and guard < 2000 \
						and day_manager.minutes_into_day < float(day_manager.DAY_START_MINUTES):
					day_manager.advance_minutes(1.0)
					guard += 1
				_check(day_manager.day == 3,
					"the 2 AM pass-out wakes on the SAME day 3 — no skipped calendar day")
				_check(day_manager.clock_text() == "6:00 AM", "woke at 6:00 AM")
				_check(player.energy == player.max_energy,
					"woke rested despite collapsing with energy left")
				_check(game_state.has_save(), "the 2 AM forced pass-out auto-saved")
				_check(not sleepy_label.visible, "the sleepy cue cleared on waking")
				for cell in POTATO_CELLS:
					_check(int(farm.get_plot(cell).get("stage", -1)) == 2,
						"plot %s did NOT double-advance for the one night" % cell)
				_enter_stage(6)
		6:
			# -- Day 3: water, talk to Harlan, then the mid-sim save with everything in flight --
			if ticks < 5:
				if ticks == 1:  # exactly once: water at home (farm-bound), then head to town
					for cell in POTATO_CELLS:
						_use_on_cell(cell, 1)
					_warp_to("town")  # zone split: Harlan lives in the Town zone
				var npc: Node = _npc_by_id("mayor_harlan")
				player.global_position = test_map.get_global_cell_center(
					test_map.world_to_cell(npc.global_position) + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active and dialogue_ui.npc == _npc_by_id("mayor_harlan"),
					"Harlan's dialogue opened mid-soak")
				var guard := 0
				while dialogue_ui.active and guard < 20:
					_drive(dialogue_ui, "use_tool")
					guard += 1
				_check(guard < 20 and not dialogue_ui.active, "Harlan's conversation closed cleanly")
				# Head home BEFORE the mid-sim save so the saved current_zone is the farm — the
				# reload below must wake up farm-bound for its bed sleep, matching a real player
				# who walks home before quitting.
				_warp_to("farm")
				# Mid-session save (the direct GameState call, same as runtime_smoke stage 81):
				# crops mid-growth, a completed player building, watered flags pending — on the
				# zone-split signature (the whole zones dict, not one map's node trio).
				_check(game_state.save_game(player, main.zones, main.get_node("Settlers")),
					"mid-sim save written")
				var parsed := SaveData.parse_save(
					FileAccess.get_file_as_string(String(game_state.save_path)))
				_check(not parsed.is_empty(), "the save file re-parses cleanly (not corrupt)")
				_enter_stage(7)
		7:
			# -- Full teardown + reboot through the real resume path (runtime_smoke's shape):
			#    since the 2026-07-11 multi-slot system that path is the title screen's
			#    explicit menu -> Load -> slot flow, driven through its real input handler --
			if ticks < 5:
				return false
			main.queue_free()
			main = null
			game_state.chosen_settlement_id = "open_plains"  # save must restore forest_edge
			day_manager.day = 1                              # save must restore day 3
			day_manager.minutes_into_day = 400.0
			_title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
			root.add_child(_title)
			current_scene = _title
			_enter_stage(8)
		8:
			# -- Restored mid-soak: drive the title Load flow, verify, then sleep into day 4 --
			if ticks == 10:  # title _ready has run; drive menu -> Load -> confirm the slot
				_check(_title._menu_entries == ["New Game", "Load Game", "Exit"],
					"the mid-soak save's slot puts Load Game on the title menu")
				_drive(_title, "move_down")  # New Game -> Load Game
				_drive(_title, "use_tool")
				_check(_title.mode == _title.Mode.LOAD, "Load panel opened")
				_check(_title._slots.size() == 1 and int(_title._slots[0]["day"]) == 3 \
						and String(_title._slots[0]["settlement_id"]) == "forest_edge",
					"the one soak slot is listed as Forest Edge day 3 (got %s)" \
						% str(_title._slots))
				_drive(_title, "use_tool")  # confirm -> load + boot main.tscn
				return false
			if ticks < 30:  # let the load's change_scene_to_file complete
				return false
			main = current_scene
			_check(main != null and main.name == "Main", "loading the slot rebooted main.tscn")
			if main == null or main.name != "Main":
				_finish()
				return true
			_fetch_world_nodes()
			_check(day_manager.day == 3, "day 3 restored")
			_check(game_state.chosen_settlement_id == "forest_edge", "settlement restored")
			# 97 = full 100 on waking from the 2 AM pass-out, minus day-3's 3 watering passes.
			_check(player.energy == 97.0,
				"mid-day energy restored exactly (97, got %.2f)" % player.energy)
			_check(player.credits == 0, "no phantom Credits appeared across the reload")
			for cell in POTATO_CELLS:
				var plot: Dictionary = farm.get_plot(cell)
				_check(int(plot.get("stage", -1)) == 2 and bool(plot.get("watered", false)),
					"plot %s restored at stage 2, watered" % cell)
			_check(structures._completed.size() == 1 and structures.is_chest_at(SHED_CELL),
				"completed shed restored as storage")
			_check(structures.shipping_contents.is_empty() and structures.sale_history.is_empty(),
				"shipping box restored empty with no phantom history")
			_check(builder.modal_gate == main.modal_gate and builder.modal_gate != null,
				"the fresh boot re-wired a fresh modal gate")
			_sleep_in_bed()
			_check(day_manager.day == 4, "slept into day 4")
			_check(int(farm.get_plot(POTATO_CELLS[0]).get("stage", -1)) == 3,
				"restored watered crops kept growing (stage 3)")
			_enter_stage(9)
		9:
			# -- Day 4: water, sleep into day 5; crops reach maturity --
			if ticks < 5:
				return false
			if ticks == 5:
				for cell in POTATO_CELLS:
					_use_on_cell(cell, 1)
				_sleep_in_bed()
				_check(day_manager.day == 5, "slept into day 5")
				for cell in POTATO_CELLS:
					_check(farm.can_harvest(cell),
						"potato at %s mature on day 5 (4 watered nights, 5 stages)" % cell)
				_enter_stage(10)
		10:
			# -- Day 5: harvest 2, place the tent, ship both potatoes, sleep -> the day-6 tick
			#    resolves growth + construction + the sale on ONE day_started emission --
			if ticks < 5:
				return false
			if ticks == 5:
				_use_on_cell(POTATO_CELLS[0], 0)  # harvest (tool-agnostic)
				_use_on_cell(POTATO_CELLS[1], 0)
				_check(player.inventory.count_of("mutant_potato") == 2, "2 potatoes harvested")
				_check(farm.can_harvest(POTATO_CELLS[2]),
					"the third potato stays standing (mature plots hold)")
				# Tent blueprint through the real input path. Note: this Builder is the FRESH
				# node the stage-7/8 reload rebuilt, so its catalog_index is back at 0 (the
				# tent) — the shed cycle from stage 3 died with the old scene, correctly (build
				#-mode browsing state is UI state, not world state, so it isn't saved).
				player.global_position = test_map.get_global_cell_center(TENT_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "south"
				_drive(builder, "build_toggle")
				_check(builder.current_id() == "shelter_tent",
					"the rebooted builder's catalog starts back on the tent")
				_check(builder.confirm_placement(), "tent blueprint placed")
				_check(player.inventory.count_of("wood") == 0, "tent spent the gathered 6 wood")
				_drive(builder, "build_toggle")
				# Load both potatoes through the real shipping UI input path.
				player.global_position = test_map.get_global_cell_center(BOX_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "north"
				player.use_tool()
				_check(shipping_ui.active, "shipping UI opened with a tent pending nearby")
				_drive(shipping_ui, "use_tool")  # row 0 = mutant_potato
				_drive(shipping_ui, "use_tool")
				_check(structures.shipping_contents == {"mutant_potato": 2},
					"both potatoes loaded into the box")
				_check(player.inventory.count_of("mutant_potato") == 0,
					"loading emptied them from the inventory")
				for i in 4:
					_drive(shipping_ui, "move_down")
				_drive(shipping_ui, "use_tool")  # Leave
				_check(not shipping_ui.active, "left the loading UI")
				# THE CONCURRENT TICK: growth + construction completion + shipping sale all ride
				# this one day_started emission (farm.gd and structures.gd subscribers).
				_sleep_in_bed()
				_check(day_manager.day == 6, "slept into day 6")
				_check(structures._pending.is_empty() and structures._completed.size() == 2,
					"tent completed on the same tick the sale resolved")
				_check(player.credits == 40,
					"sale #1 credited EXACTLY 2 x 20 Cr (no double-credit; got %d)" % player.credits)
				_check(structures.shipping_contents.is_empty(), "the sale emptied the box")
				_check(structures.sale_history.size() == 1, "one history entry after sale #1")
				if structures.sale_history.size() == 1:
					var sale: Dictionary = structures.sale_history[0]
					_check(int(sale["day"]) == 6 and sale["items"] == {"mutant_potato": 2} \
							and int(sale["total"]) == 40,
						"history entry #1 itemizes the sale (got %s)" % str(sale))
				_check(farm.can_harvest(POTATO_CELLS[2]),
					"the standing mature potato survived the same growth tick unharmed")
				_enter_stage(11)
		11:
			# -- Day 6: spend the sale Credits at Marta's (real dialogue-choice path), with a
			#    build-toggle refusal check while the STORE is the open modal this time --
			if ticks < 5:
				_warp_to("town")  # zone split: Marta's store is Town-zone content
				var npc: Node = _npc_by_id("marta")
				player.global_position = test_map.get_global_cell_center(
					test_map.world_to_cell(npc.global_position) + Vector2i(0, -1))
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active, "Marta's dialogue opened")
				_drive(dialogue_ui, "use_tool")  # reveal greet
				_drive(dialogue_ui, "use_tool")  # advance greet -> stocktake
				_drive(dialogue_ui, "use_tool")  # reveal the branch prompt
				_drive(dialogue_ui, "use_tool")  # confirm "Let's see what you've got"
				_check(store_ui.active,
					"the dialogue->store handoff still works with the modal gate in place")
				_drive(builder, "build_toggle")
				_check(not builder.active, "build_toggle is refused while the STORE is open too")
				_drive(store_ui, "move_down")  # row 0 (potato seeds) -> row 1 (dustwheat seeds)
				_check(store_ui._index == 1, "on the dustwheat-seed row")
				_drive(store_ui, "use_tool")
				_drive(store_ui, "use_tool")  # buy 2 x seed_dustwheat @ 6 Cr
				_check(player.credits == 28,
					"bought 2 dustwheat seeds with sale Credits (40 -> 28, got %d)" % player.credits)
				_check(player.inventory.count_of("seed_dustwheat") == 2, "2 dustwheat seeds held")
				_drive(store_ui, "move_up")
				_drive(store_ui, "move_up")  # 1 -> 0 -> wraps to Leave (10)
				_check(store_ui._index == 10, "wrapped up to the Leave row")
				_drive(store_ui, "use_tool")
				_check(not store_ui.active, "left the store")
				_enter_stage(12)
		12:
			# -- Day 6: harvest the last potato, start the second crop, ship, sleep -> sale #2 --
			if ticks < 5:
				_warp_to("farm")  # home from the store: the day's work is all farm-zone
				return false
			if ticks == 5:
				_use_on_cell(POTATO_CELLS[2], 0)  # harvest
				_check(player.inventory.count_of("mutant_potato") == 1, "last potato harvested")
				var seed_slot := _hotbar_index_of("seed_dustwheat")
				_check(seed_slot >= 0, "the bought dustwheat seeds landed in a hotbar slot")
				for cell in DUSTWHEAT_CELLS:
					_use_on_cell(cell, 0)          # till
					_use_on_cell(cell, seed_slot)  # plant
					_use_on_cell(cell, 1)          # water
				for cell in DUSTWHEAT_CELLS:
					var plot: Dictionary = farm.get_plot(cell)
					_check(String(plot.get("crop_id", "")) == "dustwheat"
							and bool(plot.get("watered", false)),
						"dustwheat planted+watered at %s" % cell)
				_check(player.inventory.count_of("seed_dustwheat") == 0, "both seeds planted")
				# Ship the last potato.
				player.global_position = test_map.get_global_cell_center(BOX_STAND)
				player.velocity = Vector2.ZERO
				player.facing = "north"
				player.use_tool()
				_check(shipping_ui.active, "shipping UI opened for the second load")
				_drive(shipping_ui, "use_tool")
				_check(structures.shipping_contents == {"mutant_potato": 1}, "third potato loaded")
				for i in 4:
					_drive(shipping_ui, "move_down")
				_drive(shipping_ui, "use_tool")  # Leave
				_sleep_in_bed()
				_check(day_manager.day == 7, "slept into day 7 — six full days end to end")
				_check(player.credits == 48,
					"sale #2 credited EXACTLY 20 more (28 + 20 = 48, got %d)" % player.credits)
				_check(structures.sale_history.size() == 2,
					"two separate morning sales resolved across the soak")
				if structures.sale_history.size() == 2:
					var sale: Dictionary = structures.sale_history[1]
					_check(int(sale["day"]) == 7 and sale["items"] == {"mutant_potato": 1} \
							and int(sale["total"]) == 20,
						"history entry #2 itemizes sale #2 (got %s)" % str(sale))
				for cell in DUSTWHEAT_CELLS:
					_check(int(farm.get_plot(cell).get("stage", -1)) == 1,
						"dustwheat at %s advanced overnight alongside the sale" % cell)
				_enter_stage(13)
		13:
			# -- Final integrity: nothing stuck, nothing left open, clean save hygiene --
			if ticks < 5:
				player.global_position = test_map.to_global(test_map.get_spawn_position())
				player.velocity = Vector2.ZERO
				return false
			if ticks == 5:
				_check(day_manager.day == 7, "day counter held at 7")
				_check(player.energy == player.max_energy, "woke rested on the final morning")
				for surface in [builder, dialogue_ui, store_ui, shipping_ui]:
					_check(not bool(surface.active), "%s ended the soak closed" % surface.name)
				_check(not main.modal_gate.is_any_open(), "the modal gate agrees nothing is open")
				var parsed := SaveData.parse_save(
					FileAccess.get_file_as_string(String(game_state.save_path)))
				_check(not parsed.is_empty(), "the final auto-save re-parses cleanly")
				_walk_start_pos = player.global_position
				Input.action_press("move_left")
				return false
			if ticks >= 90:  # generous: the last tool swing's ~30-tick animation lock must clear
				# before held movement can take effect, and the walk needs real distance after it
				Input.action_release("move_left")
				_check(player.global_position.x < _walk_start_pos.x - 8.0,
					"the player walks normally after 6 soaked days (never stuck)")
				_delete_test_saves()
				_check(not game_state.has_save(), "test save file cleaned up")
				_finish()
				return true
		GATE_WALK_STAGE:
			# -- Zone-transition Stage 3: one REAL gate-cell crossing per remaining hop of
			#    _gate_route (see GATE_WALK_STAGE's doc). Standing the player on the authored
			#    gate cell lets player.gd's own _physics_process detection fire
			#    zone_exit_requested → main._on_zone_exit_requested → zone_fade.play →
			#    _bind_zone — the genuine crossing path, asserted to fire EXACTLY once per hop
			#    via the signal counter connected in _fetch_world_nodes. --
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


## Fetches every live node the soak drives — called on first boot and again after the reload.
## Since the zone split main.tscn holds 4 sibling zone maps (main.zones); this soak's world
## refs start on the FARM zone's nodes and are re-pointed per zone by _rebind_zone_refs as the
## playthrough crosses (the day-1 round trip through the real gate walk, later trips via
## _warp_to — the zone-transition plan's Stage 3, landed).
func _fetch_world_nodes() -> void:
	player = main.get_node("Player")
	# Count real crossing signals for the Stage 3 gate-walk stages (2/3 via stage 20). Re-run
	# after the reload too: the rebooted scene has a FRESH Player node, so no double-connect.
	player.zone_exit_requested.connect(
		func(_z: String, _c: Vector2i) -> void: _gate_exit_signals += 1)
	test_map = main.zones["farm"]["map"]
	farm = main.zones["farm"]["farm"]
	structures = main.zones["farm"]["structures"]
	npcs = main.zones["farm"]["npcs"]
	builder = main.get_node("Builder")
	dialogue_ui = main.get_node("DialogueUI")
	store_ui = main.get_node("StoreUI")
	shipping_ui = main.get_node("ShippingUI")
	menu_screen = main.get_node("MenuScreen")
	hud = main.get_node("HUD")


## Re-points this soak's world refs at `zone_id`'s nodes (no player repositioning) — shared by
## both warp paths below.
func _rebind_zone_refs(zone_id: String) -> void:
	test_map = main.zones[zone_id]["map"]
	farm = main.zones[zone_id]["farm"]
	structures = main.zones[zone_id]["structures"]
	npcs = main.zones[zone_id]["npcs"]


## Rebinds the player into `zone_id` through main.gd's real _bind_zone (the same rebind a
## gate crossing performs, minus the fade) and re-points this soak's world refs at that zone's
## nodes. Needed since the zone split: the town NPCs and Marta's store live in the Town zone's
## own map now, while all farming/building/sleeping stays in the farm zone. The day-1 round
## trip goes through _begin_gate_walk below instead (the REAL gate-cell path); the later town
## trips use this direct shortcut once that's covered.
func _warp_to(zone_id: String) -> void:
	main._bind_zone(zone_id)
	_rebind_zone_refs(zone_id)


## Kicks off a real gate-cell walk (see GATE_WALK_STAGE's doc): queues `route`'s hops for the
## stage-20 sub-machine, which enters `next_stage` after the last arrival, world refs rebound.
func _begin_gate_walk(route: Array, next_stage: int) -> void:
	_gate_route = route.duplicate()
	_gate_next_stage = next_stage
	_enter_stage(GATE_WALK_STAGE)


## One real player.use_tool() against `cell`: stands the player on the cell directly north,
## faces south, selects the hotbar slot, swings. The interaction resolves synchronously inside
## use_tool() (only the animation lock persists across frames), so consecutive calls in one
## tick each land — the same state transitions as spaced-out presses, without per-swing stages.
## get_global_cell_center (not cell_to_world_center) since the zone split: zones sit at
## sibling position offsets, so a local cell center is only world-space by luck at the origin.
func _use_on_cell(cell: Vector2i, hotbar_index: int) -> void:
	player.global_position = test_map.get_global_cell_center(cell + Vector2i(0, -1))
	player.velocity = Vector2.ZERO
	player.facing = "south"
	player.inventory.select_hotbar(hotbar_index)
	player.use_tool()


## The real bed interaction: stand south of the bed, face it, use_tool -> sleep + auto-save.
func _sleep_in_bed() -> void:
	player.global_position = test_map.get_global_cell_center(BED_STAND)
	player.velocity = Vector2.ZERO
	player.facing = "north"
	player.use_tool()


## Fabricated action event through a node's real _unhandled_input — the established convention
## from tools/runtime_smoke.gd (Input.action_press() doesn't produce _unhandled_input callbacks
## in --script mode).
func _drive(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)


## Wipes the test-only saves directory (every file, then the directory itself) — the
## multi-slot analogue of the old single-file delete_save() hygiene. Safe on a missing dir.
func _delete_test_saves() -> void:
	var abs_dir := ProjectSettings.globalize_path(String(game_state.saves_dir))
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file_name in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file_name))
	DirAccess.remove_absolute(abs_dir)


func _hotbar_index_of(item_id: String) -> int:
	for i in player.inventory.HOTBAR_SIZE:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item_id:
			return i
	return -1


## Looks up a spawned NPC by roster id — in the currently-bound zone's roster by default, or
## in an explicit zone's (the zone split moved all NPCs out of the farm zone, so a farm-bound
## stage that needs a town NPC node passes zone_id explicitly).
func _npc_by_id(id: String, zone_id: String = "") -> Node:
	var roster: Node = npcs if zone_id == "" else main.zones[zone_id]["npcs"]
	for npc in roster.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _finish() -> void:
	if failures.is_empty():
		print("SOAK TEST: all checks passed (6 in-game days, 2 sales, 2 builds, 1 reload).")
		quit(0)
	else:
		for failure in failures:
			print("SOAK TEST FAIL: %s" % failure)
		quit(1)
