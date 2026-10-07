extends SceneTree
## Milestone B placeables smoke (2026-10-07): crafted objects through the REAL player paths —
## place with the use button, interact with the interact path, pick up with a pickaxe swing —
## plus the clock and the save file:
##   chest: place, open the storage screen, move a stack in and back out;
##   kiln -> smelter -> metal bar -> a tier-2 axe upgrade (the whole tool-upgrade chain);
##   sprinkler: waters the crop beside it overnight with no watering can;
##   gravel path: lay, refuse tilling, lift with the pickaxe;
##   save + reload: chest contents, a running machine and the floor all persist.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/placeables_smoke.gd

## crafting.gd references the Events autoload, so it's loaded at runtime (a --script tool compiles
## before autoload names exist; a preload here fails to compile).
var Crafting: GDScript = null

const CHEST := Vector2i(22, 6)
const KILN := Vector2i(24, 6)
const SMELTER := Vector2i(26, 6)
const SPRINKLER := Vector2i(30, 9)
const CROP := Vector2i(30, 10)  # south of the sprinkler
const PATH := Vector2i(34, 6)

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var test_map: Node
var objects: Node
var farm: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _stored_wood := 0


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://placeables_smoke_saves"
	game_state.legacy_save_path = "user://placeables_smoke_saves/legacy.json"
	game_state.save_path = "user://placeables_smoke_saves/slot_1.json"
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _refs() -> void:
	player = main.get_node("Player")
	test_map = main.zones["farm"]["map"]
	objects = test_map.get_node("Objects")
	farm = test_map.get_node("Farm")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _physics_process(_delta: float) -> bool:
	ticks += 1
	match stage:
		0:
			if ticks < 10:
				return false
			_refs()
			Crafting = load("res://scripts/crafting.gd")
			day_manager.time_paused = true
			day_manager.minutes_into_day = 8 * 60.0
			for pair in [["crate_chest", 1], ["kiln", 1], ["smelter", 1], ["scrap_sprinkler", 1],
					["gravel_path", 3], ["wood", 30], ["scrap_metal", 10], ["seed_rain_radish", 1]]:
				player.inventory.add_item(pair[0], pair[1])
			# -- Chest: place it, open the storage screen through Interact, move stacks --
			_use_item_on(CHEST, "crate_chest")
			_check(objects.kind_at(CHEST) == "placed_crate_chest", "chest placed with the use button")
			_check(player.inventory.count_of("crate_chest") == 0, "placing used the chest item")
			_face(CHEST)
			player.interact()
			var storage_ui: Node = main.storage_ui
			_check(storage_ui.active, "interacting opens the storage screen")
			var wood_slot := _slot_of("wood")
			_stored_wood = player.inventory.count_of("wood")  # the settlement bonus + the 30 given
			_check(storage_ui.transfer_at(27 + wood_slot), "moved the wood stack into the chest")
			_check(objects.storage_at(CHEST).count_of("wood") == _stored_wood \
					and player.inventory.count_of("wood") == 0,
				"all %d wood now in the chest" % _stored_wood)
			_check(storage_ui.transfer_at(0), "moved it back out")
			_check(player.inventory.count_of("wood") == _stored_wood, "the wood is back in the pack")
			storage_ui.transfer_at(27 + _slot_of("wood"))  # leave it stored for the save check
			storage_ui.close()
			_check(not storage_ui.active, "the storage screen closes")
			player.inventory.add_item("wood", 30)  # fresh wood for the kiln
			# -- Kiln: wood -> charcoal --
			_use_item_on(KILN, "kiln")
			_check(objects.kind_at(KILN) == "placed_kiln", "kiln placed")
			_select("wood")
			_face(KILN)
			player.interact()
			_check(not objects.machine_state_at(KILN).is_empty(), "the kiln took a batch of wood")
			_check(player.inventory.count_of("wood") == 20, "10 wood went in")
			day_manager.advance_minutes(61.0)
			_face(KILN)
			player.interact()
			_check(player.inventory.count_of("charcoal") == 1, "collected 1 charcoal after an hour")
			# -- Smelter: scrap + charcoal -> metal bar --
			_use_item_on(SMELTER, "smelter")
			_select("scrap_metal")
			_face(SMELTER)
			player.interact()
			_check(not objects.machine_state_at(SMELTER).is_empty(), "the smelter took scrap + fuel")
			_check(player.inventory.count_of("charcoal") == 0, "the charcoal was burnt as fuel")
			day_manager.advance_minutes(121.0)
			_face(SMELTER)
			player.interact()
			_check(player.inventory.count_of("metal_bar") == 1, "collected a metal bar")
			# -- The tool-upgrade chain end to end (5 bars needed; top up the rest) --
			player.inventory.add_item("metal_bar", 4)
			player.set_credits(300)
			_check(Crafting.craft("upgrade_axe_2", player, {}) == "", "upgraded the axe to tier 2")
			_check(player.inventory.selected_tool_tier() >= 1, "inventory still sane")
			# -- Pick the kiln back up with the pickaxe --
			_select_tool("pickaxe")
			_face(KILN)
			player.use_tool()
			_check(objects.kind_at(KILN) == "", "the pickaxe picked the kiln up")
			objects.collect_all_pickups(player.inventory)
			_check(player.inventory.count_of("kiln") == 1, "the kiln came back as an item")
			# -- Sprinkler waters a planted crop overnight --
			_select_tool("hoe")
			_face(CROP)
			player.use_tool()
			_use_item_on(CROP, "seed_rain_radish")
			_check(String(farm.get_plot(CROP).get("crop_id", "")) == "rain_radish", "radish planted")
			_use_item_on(SPRINKLER, "scrap_sprinkler")
			_check(objects.kind_at(SPRINKLER) == "placed_scrap_sprinkler", "sprinkler placed")
			# -- Gravel path --
			_use_item_on(PATH, "gravel_path")
			_check(test_map.has_floor(PATH), "gravel laid")
			_check(not farm.can_till(PATH), "paths can't be tilled")
			_select_tool("pickaxe")
			_face(PATH)
			player.use_tool()
			_check(not test_map.has_floor(PATH), "the pickaxe lifts the path")
			_use_item_on(PATH, "gravel_path")
			# -- Load a batch to persist across the save --
			_select("scrap_metal")
			player.inventory.add_item("scrap_metal", 10)
			player.inventory.add_item("charcoal", 1)
			_face(SMELTER)
			player.interact()
			_check(not objects.machine_state_at(SMELTER).is_empty(), "a batch is running at save time")
			# -- Sleep: the sprinkler should water the crop for day 2 --
			day_manager.time_paused = false
			player._sleep_in_bed()
			_check(day_manager.day == 2, "slept into day 2")
			stage = 1
			ticks = 0
		1:
			if ticks < 3:
				return false  # let the deferred sprinkler pass run
			_check(farm.is_watered(CROP), "the sprinkler watered the radish this morning")
			_check(game_state.save_game(player, main.zones, main.get_node("Settlers"),
				main.get_node("Animals"), main.get_node("Affinity")), "saved")
			main.queue_free()
			main = null
			stage = 2
			ticks = 0
		2:
			if ticks < 3:
				return false
			game_state.load_save_from_disk()
			_boot()
			stage = 3
			ticks = 0
		3:
			if ticks < 10:
				return false
			_refs()
			_check(objects.kind_at(CHEST) == "placed_crate_chest", "the chest survived the reload")
			_check(objects.storage_at(CHEST) != null \
					and objects.storage_at(CHEST).count_of("wood") == _stored_wood,
				"its %d wood survived the reload" % _stored_wood)
			_check(not objects.machine_state_at(SMELTER).is_empty(), "the smelter's batch survived")
			_check(test_map.has_floor(PATH), "the gravel path survived")
			_check(objects.kind_at(SPRINKLER) == "placed_scrap_sprinkler", "the sprinkler survived")
			_finish()
			return true
	return false


func _face(cell: Vector2i) -> void:
	player.global_position = test_map.get_global_cell_center(cell + Vector2i(0, -1))
	player.velocity = Vector2.ZERO
	player.facing = "south"
	player.using_tool = false


func _select(item_id: String) -> void:
	var i := _slot_of(item_id)
	if i >= player.inventory.HOTBAR_SIZE:
		player.inventory.move_slot(i, player.inventory.HOTBAR_SIZE - 1)
		i = player.inventory.HOTBAR_SIZE - 1
	player.inventory.select_hotbar(i)


func _select_tool(kind: String) -> void:
	for i in player.inventory.HOTBAR_SIZE:
		if load("res://scripts/item_db.gd").tool_kind(String(player.inventory.get_slot(i).get("item_id", ""))) == kind:
			player.inventory.select_hotbar(i)
			return


func _use_item_on(cell: Vector2i, item_id: String) -> void:
	_select(item_id)
	_face(cell)
	player.use_tool()


func _slot_of(item_id: String) -> int:
	for i in player.inventory.TOTAL_SLOTS:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item_id:
			return i
	return -1


func _wipe() -> void:
	var dir := ProjectSettings.globalize_path("user://placeables_smoke_saves")
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)


func _finish() -> void:
	_wipe()
	if failures.is_empty():
		print("PLACEABLES SMOKE: all checks passed (chest storage, kiln -> smelter -> axe upgrade, pickup, sprinkler, path, save/reload).")
		quit(0)
	else:
		for f in failures:
			print("PLACEABLES SMOKE FAIL: " + f)
		quit(1)
