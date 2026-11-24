extends SceneTree
## Fishing smoke (docs/FISHING.md): boots the real game (Forest Edge) and fishes the town pond
## through real input — Input.action_press/release on use_tool, the way a held key reads — end
## to end:
##   0. Dad's rod is in the farm chest on day 1 (and the morning toast says so); Marta stocks one.
##      The chest is opened with Use and the rod taken through the real storage screen.
##   1. In town, on the dock facing the pond: the prompt says Cast. Hold Use: the power meter
##      fills. Release: the bobber flies, lands in the pond, 2 energy spent.
##   2. Wait for the real bite (no forced timing): "!" over the player, the hook window open.
##   3. Press Use: the reel panel opens as a modal (the clock stops). Play it by holding and
##      releasing Use, easing off when the fish tenses and runs, to a catch.
##   4. The fish is in the pack, Foraging XP is 3 + 3 x difficulty, the journal's Fish page
##      counts it, the has_fished flag is set. Cook Grilled Fish on the CRAFT tab.
##   5. Fail paths: hold Use straight through a fight and the line snaps (the rod's fine); a
##      junk bite lands at once (a can -> Scrap Metal, 1 XP); moving reels in; casting at dry
##      land says "No water there" and costs nothing.
##   6. Tap mode (Settings "Use button: Tap"): tap to charge, tap to cast, tap to hook; Esc cuts
##      the fish loose.
##   7. Save and reload: the catch log survives; the rod isn't granted twice.
## With WH_SHOT_DIR set (run windowed under xvfb) it also saves screenshots of the cast, the
## bite, the reel and the journal page.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/fishing_smoke.gd

const FishDB := preload("res://scripts/fish_db.gd")
const RecipeDB := preload("res://scripts/recipe_db.gd")
const ShopDB := preload("res://scripts/shop_db.gd")

const CHEST_STAND := Vector2i(16, 5)  # facing north -> the farm chest at (16,4)
const DOCK := Vector2i(26, 12)         # the town pond's dock, facing east over the water
const MAX_TICKS_PER_STAGE := 1500

var game_state: Node
var day_manager: Node
var settings: Node
var main: Node
var player: Node
var fishing: Node
var failures: Array[String] = []
var messages: Array[String] = []
var stage := 0
var ticks := 0
var _finished := false
var _energy := 0.0
var _xp := 0
var _scrap := 0
var _caught_log: Dictionary = {}
var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var _shots: Dictionary = {}


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	settings = root.get_node("Settings")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://fishing_smoke_saves"
	game_state.legacy_save_path = "user://fishing_smoke_saves/legacy.json"
	game_state.save_path = "user://fishing_smoke_saves/slot_1.json"
	settings.set_value("access/use_mode", "hold", false)
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	root.get_node("Events").message.connect(func(text: String) -> void: messages.append(text))
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("fishing_smoke_saves"):
		for f in DirAccess.get_files_at("user://fishing_smoke_saves"):
			DirAccess.remove_absolute("user://fishing_smoke_saves/" + f)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	print("[fishing smoke] stage %d" % to_stage)
	stage = to_stage
	ticks = 0


func _state() -> int:
	return int(fishing.state)


func _st(name: String) -> int:
	return int(fishing.State[name])


func _stand(zone_id: String, cell: Vector2i, facing: String) -> void:
	if player.current_zone_id != zone_id:
		main._bind_zone(zone_id)
	player.global_position = main.zones[zone_id]["map"].get_global_cell_center(cell)
	player.velocity = Vector2.ZERO
	player.facing = facing


func _hold(item_id: String) -> void:
	var inv = player.inventory
	for i in inv.slots.size():
		if String(inv.get_slot(i).get("item_id", "")) == item_id:
			if i >= inv.HOTBAR_SIZE:
				inv.move_slot(i, inv.HOTBAR_SIZE - 1)
				i = inv.HOTBAR_SIZE - 1
			inv.select_hotbar(i)
			return


func _shot(name: String) -> void:
	if shot_dir == "" or _shots.has(name):
		return
	_shots[name] = true
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(shot_dir.path_join("fishing_%s.png" % name))
		print("[fishing smoke] screenshot %s" % name)


## The careful angler: reel while the fish rests and tension is under the sweet spot's middle;
## give line when it tenses or runs.
func _reel_policy() -> bool:
	var s: Dictionary = fishing._reel_state
	if s.is_empty() or String(s.get("phase", "")) != "rest":
		return false
	var band: Vector2 = FishDB.sweet_spot(fishing._reel_params, float(s["t"]))
	return float(s["tension"]) < (band.x + band.y) * 0.5


func _find_label(node: Node, needle: String) -> bool:
	for child in node.get_children():
		if child is Label and String((child as Label).text).contains(needle):
			return true
		if _find_label(child, needle):
			return true
	return false


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if _finished:
		return true
	if ticks > MAX_TICKS_PER_STAGE:
		_check(false, "TIMED OUT (watchdog)")
		_finish()
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			fishing = main.fishing
			_check(fishing != null and player.fishing == fishing, "fishing is wired to the player")
			_check(main.get_node("MenuScreen").fishing == fishing, "and to the journal")
			var structures: Node = main.zones["farm"]["structures"]
			_check(structures.chest_inventory.count_of("fishing_rod") == 1, "Dad's rod is in the farm chest")
			_check(player.inventory.count_of("fishing_rod") == 0, "not in the pack yet")
			_check(ShopDB.stock_ids(day_manager.season()).has("fishing_rod"), "Marta stocks a rod")
			# Open the chest the real way and take the rod out through the storage screen.
			_stand("farm", CHEST_STAND, "north")
			player.use_tool()
			_check(main.storage_ui.active and main.storage_ui.storage() == structures.chest_inventory,
				"Use on the chest opens it")
			var idx := -1
			for i in structures.chest_inventory.slots.size():
				if String(structures.chest_inventory.get_slot(i).get("item_id", "")) == "fishing_rod":
					idx = i
			_check(idx >= 0 and main.storage_ui.transfer_at(idx), "the rod comes out of the chest")
			main.storage_ui.close()
			_check(player.inventory.count_of("fishing_rod") == 1, "the rod is in the pack")
			_hold("fishing_rod")
			_next(1)
		1:
			if ticks < 5:
				return false
			_stand("town", DOCK, "east")
			day_manager.minutes_into_day = 9 * 60.0
			_next(2)
		2:
			if ticks < 4:
				return false
			_check(String(player.describe_action().get("use", "")) == "Cast", "the prompt says Cast (%s)" % [player.describe_action()])
			_check(main.zones["town"]["map"].water_kind_at(DOCK + Vector2i(1, 0)) == "pond", "the town pond is a pond")
			fishing.forced_pick = {"kind": "fish", "id": "mud_minnow"}
			_energy = float(player.energy)
			_xp = int(main.skills.xp.get("foraging", 0))
			Input.action_press("use_tool")
			_next(3)
		3:
			# Holding: the meter charges over a second.
			if ticks == 2:
				_check(_state() == _st("CHARGING"), "holding Use with the rod charges a cast (state %d)" % _state())
			if ticks == 30:
				_check(fishing.power > 0.3 and fishing.power < 0.7, "half a second: half power (%.2f)" % fishing.power)
				_shot("1_charge")
			if ticks < 70:
				return false
			_check(is_equal_approx(fishing.power, 1.0), "a full second: full power")
			Input.action_release("use_tool")
			_next(4)
		4:
			if ticks == 2:
				_check(_state() == _st("CASTING"), "releasing casts (state %d)" % _state())
				_check(is_equal_approx(_energy - float(player.energy), 2.0), "a cast costs 2 energy (%.2f)" % (_energy - float(player.energy)))
				_check(fishing._target_cell == DOCK + Vector2i(4, 0), "full power flies 4 cells")
			if _state() == _st("WAITING") and ticks > 40:
				_shot("2_cast")
			if _state() == _st("BITE"):
				_check(fishing._alert.visible, "the '!' pops over the player")
				_check(fishing._bobber.frame == 1, "the bobber dips")
				_check(String(player.describe_action().get("use", "")) == "Hook it!", "the prompt says hook it")
				_shot("3_bite")
				Input.action_press("use_tool")
				_next(5)
			elif ticks > 8 * 60:
				_check(false, "the bite came within 6 s of landing")
				_finish()
		5:
			if ticks == 2:
				_check(_state() == _st("REELING"), "Use in the window hooks it (state %d)" % _state())
				_check(fishing.reel_ui.active and fishing.reel_ui.fish_id == "mud_minnow", "the reel panel is up")
				_check(main.modal_gate.is_any_open(), "the reel is a modal surface")
			if ticks == 4:
				_check(day_manager.time_paused, "the clock stops while reeling")
			if _state() == _st("REELING"):
				if _reel_policy():
					Input.action_press("use_tool")
				else:
					Input.action_release("use_tool")
				if ticks == 90:
					_shot("4_reel")
				return false
			Input.action_release("use_tool")
			_check(fishing.count_of("mud_minnow") == 1, "landed: the log counts it")
			_check(player.inventory.count_of("mud_minnow") == 1, "the minnow is in the pack")
			_check(int(main.skills.xp.get("foraging", 0)) - _xp == FishDB.catch_xp("mud_minnow"),
				"Foraging XP 3 + 3 x 1 (%d)" % (int(main.skills.xp.get("foraging", 0)) - _xp))
			_check(main.dialogue_context()["flags"].has("has_fished"), "the has_fished flag")
			_check(not main.dialogue_context()["flags"].has("angler"), "not an angler yet")
			_check(messages.has("Dad's old fishing rod is in the chest."), "the day-1 toast mentioned the rod")
			_check(not fishing.reel_ui.active, "the reel panel closed")
			var menu: Node = main.get_node("MenuScreen")
			menu.open_menu(menu.TAB_JOURNAL)
			menu.journal_page = menu.JOURNAL_FISH
			menu.fish_index = FishDB.ids().find("mud_minnow")
			menu._refresh()
			_next(6)
		6:
			var menu: Node = main.get_node("MenuScreen")
			if ticks == 3:
				_check(_find_label(menu._journal_tab, "1 of 13 caught"), "the journal's Fish page counts it")
				_check(_find_label(menu._journal_tab, "Caught 1"), "and shows the count")
				_shot("5_journal")
			if ticks < 6:
				return false
			menu.close()
			# Cook Grilled Fish on the CRAFT tab.
			menu.open_menu(menu.TAB_CRAFT)
			menu._select_recipe(RecipeDB.ids().find("grilled_fish"))
			menu._craft_selected()
			menu.close()
			_check(player.inventory.count_of("grilled_fish") == 1, "cooked Grilled Fish")
			_check(player.inventory.count_of("mud_minnow") == 0, "from the minnow")
			# -- Snap: hold straight through --
			_hold("fishing_rod")
			fishing.forced_pick = {"kind": "fish", "id": "iron_pike"}
			fishing.forced_bite_seconds = 0.5
			Input.action_press("use_tool")
			_next(7)
		7:
			if ticks == 20:
				Input.action_release("use_tool")
			if _state() == _st("BITE"):
				Input.action_press("use_tool")
				_next(8)
		8:
			# Never let go: the line snaps.
			if _state() == _st("REELING") or ticks < 3:
				return false
			_check(messages.has("The line snapped. The fish is gone; the rod's fine."), "the line snaps")
			_check(fishing.count_of("iron_pike") == 0, "no pike")
			_check(player.inventory.count_of("fishing_rod") == 1, "the rod is fine")
			Input.action_release("use_tool")
			_next(9)
		9:
			# -- Junk: a can, caught at once --
			if ticks < 3:
				return false
			_scrap = int(player.inventory.count_of("scrap_metal"))
			_xp = int(main.skills.xp.get("foraging", 0))
			fishing.forced_pick = {"kind": "junk", "id": "tin_can", "item": "scrap_metal", "count": 1,
				"line": "A rusted can. Not even beans. Scrap, then."}
			Input.action_press("use_tool")
			_next(10)
		10:
			if ticks == 15:
				Input.action_release("use_tool")
			if _state() == _st("BITE"):
				Input.action_press("use_tool")
				_next(11)
		11:
			if ticks < 3:
				return false
			Input.action_release("use_tool")
			_check(_state() == _st("IDLE"), "junk lands at once, no reel")
			_check(int(player.inventory.count_of("scrap_metal")) == _scrap + 1, "the can is Scrap Metal")
			_check(int(main.skills.xp.get("foraging", 0)) - _xp == 1, "junk gives 1 XP")
			_check(messages.has("A rusted can. Not even beans. Scrap, then."), "with a wry line")
			_next(12)
		12:
			# -- Moving reels in --
			if ticks == 3:
				fishing.forced_bite_seconds = 30.0
				Input.action_press("use_tool")
			if ticks == 15:
				Input.action_release("use_tool")
			if ticks == 50:
				_check(_state() == _st("WAITING"), "the line is out")
				Input.action_press("move_left")
			if ticks == 53:
				Input.action_release("move_left")
				_check(_state() == _st("IDLE"), "moving reels in")
				fishing.forced_bite_seconds = -1.0
			if ticks == 60:
				# -- Dry land: no water, no energy --
				_stand("town", Vector2i(12, 10), "south")
				_energy = float(player.energy)
				Input.action_press("use_tool")
			if ticks == 70:
				Input.action_release("use_tool")
			if ticks == 75:
				_check(_state() == _st("IDLE"), "a cast at dry land ends at once")
				_check(is_equal_approx(_energy, float(player.energy)), "and costs nothing")
				_next(13)
		13:
			# -- Tap mode: every hold becomes a tap --
			if ticks <= 3 and player.using_tool:
				ticks = 0  # let the dry cast's swing finish first
				return false
			if ticks == 3:
				settings.set_value("access/use_mode", "toggle", false)
				_stand("town", DOCK, "east")
				fishing.forced_pick = {"kind": "fish", "id": "rustgill_carp"}
				fishing.forced_bite_seconds = 0.6
				Input.action_press("use_tool")
			if ticks == 5:
				Input.action_release("use_tool")
			if ticks == 25:
				_check(_state() == _st("CHARGING"), "tap mode: a tap starts the charge (state %d)" % _state())
				Input.action_press("use_tool")
			if ticks == 27:
				Input.action_release("use_tool")
			if ticks == 30:
				_check(_state() == _st("CASTING") or _state() == _st("WAITING"), "a second tap casts (state %d)" % _state())
			if ticks > 30 and _state() == _st("BITE"):
				Input.action_press("use_tool")
				_next(14)
		14:
			if ticks == 2:
				Input.action_release("use_tool")
			if ticks == 6:
				_check(_state() == _st("REELING"), "a tap hooks it (state %d)" % _state())
				_check(bool(fishing._reel_held), "and the latch reels")
				Input.action_press("ui_cancel")
			if ticks == 8:
				Input.action_release("ui_cancel")
				_check(_state() == _st("IDLE") and messages.has("You let it go."), "Esc cuts it loose")
				_check(not bool(player._use_latched), "the latch is released")
				settings.set_value("access/use_mode", "hold", false)
				fishing.forced_bite_seconds = -1.0
				_caught_log = fishing.caught.duplicate()
				_check(game_state.save_game(player, main.zones, main.get_node("Settlers"),
					main.get_node("Animals"), main.get_node("Affinity")), "saved")
				main.queue_free()
				main = null
				_next(15)
		15:
			if ticks < 3:
				return false
			game_state.load_save_from_disk()
			_boot()
			_next(16)
		16:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			fishing = main.fishing
			_check(fishing.caught == _caught_log, "the catch log survives a reload (%s)" % [fishing.caught])
			_check(main.dialogue_context()["flags"].has("has_fished"), "and the flag")
			var rods := int(player.inventory.count_of("fishing_rod")) \
				+ int(main.zones["farm"]["structures"].chest_inventory.count_of("fishing_rod"))
			_check(rods == 1, "one rod, not two (%d)" % rods)
			fishing.load_state({})
			_check(fishing.caught.is_empty() and not fishing.old_mayor, "an old save loads with an empty log")
			_finish()
			return true
	return false


func _finish() -> void:
	_finished = true
	for action in ["use_tool", "ui_cancel", "move_left"]:
		Input.action_release(action)
	if settings != null:
		settings.set_value("access/use_mode", "hold", false)
	_wipe()
	if failures.is_empty():
		print("FISHING SMOKE: all checks passed (rod in the chest, cast, bite, hook, reel to a catch, XP, journal, flag, Grilled Fish, snap, junk, reel-in, dry cast, tap mode, save/reload).")
		quit(0)
	else:
		for f in failures:
			print("FISHING SMOKE FAIL: %s" % f)
		quit(1)


func _finalize() -> void:
	if not _finished:
		print("FISHING SMOKE FAIL: the run ended at stage %d before finishing" % stage)
		for f in failures:
			print("FISHING SMOKE FAIL: %s" % f)
