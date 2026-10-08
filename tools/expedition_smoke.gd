extends SceneTree
## Milestone C expedition smoke (2026-10-08): the whole ruins loop through the real player paths.
##   1. Kael's truck at the north checkpoint: Interact -> the prompt -> ride out.
##   2. The ruins level is built: terrain, objects, enemies, banner.
##   3. An enemy left alone with the player detects, chases and hurts them; i-frames hold.
##   4. A machete kills it: kill counted, combat XP.
##   5. A container is searched once, and a rad barrel irradiates.
##   6. A lore note is picked up and read.
##   7. The subway stairs take the player to depth 2; Kael's truck takes them home with the
##      haul kept.
##   8. A second run ends in death: Kael carries the player home, the next morning comes at
##      10% HP, and that run's pickups are gone.
##   9. The expedition save section survives a save + reload.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/expedition_smoke.gd

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _target: Node = null
var _hp_before := 0.0
var _haul_item := ""
var _haul_before := 0
var _day_before := 0
var _xp_before := 0


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://expedition_smoke_saves"
	game_state.legacy_save_path = "user://expedition_smoke_saves/legacy.json"
	game_state.save_path = "user://expedition_smoke_saves/slot_1.json"
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	stage = to_stage
	ticks = 0


func _physics_process(_delta: float) -> bool:
	ticks += 1
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			day_manager.time_paused = false
			day_manager.minutes_into_day = 9 * 60.0
			var path_objects: Node = main.zones["path"]["objects"]
			_check(path_objects.count_kinds(["kaels_truck"]) == 1, "Kael's truck is parked in the path zone")
			main._bind_zone("path", Vector2i(11, 3))
			player.facing = "north"
			player.interact()
			_check(main.confirm_ui.active, "the truck asks whether to ride out")
			main.confirm_ui.choose(0)
			_next(1)
		1:
			if ticks < 45:
				return false
			var ex: Node = main.expedition
			_check(ex.active and ex.depth == 1, "an expedition is under way at depth 1")
			_check(player.current_zone_id == "ruins", "the player is in the ruins")
			_check(main.ruins["enemies"].live_count() > 0, "the level has enemies")
			_check(main.ruins["objects"].count_kinds(["kaels_truck"]) == 1, "Kael's truck waits at the entry")
			_check(main.ruins["objects"].count_kinds(["subway_stairs"]) == 1, "the stairs exist")
			_check(player.inventory.count_of("rusty_pipe") == 1, "Kael's first-ride pipe")
			# Leave one enemy alone with the player: it should notice, close in and strike.
			_target = _nearest_enemy()
			_check(_target != null, "found an enemy")
			if _target != null:
				for e in main.ruins["enemies"].live_enemies():
					if e != _target:
						e.queue_free()
				player.global_position = _target.global_position + Vector2(-20, 0)
				player.facing = "east"
				_hp_before = player.hp
			_next(2)
		2:
			if ticks < 240 and player.hp >= _hp_before:
				return false
			_check(player.hp < _hp_before, "the enemy found and hurt the player (hp %.0f -> %.0f)" % [_hp_before, player.hp])
			var after_hit: float = player.hp
			player.take_hit(5, player.global_position + Vector2(8, 0), 50.0)
			_check(is_equal_approx(player.hp, after_hit), "i-frames swallow a second hit right away")
			# Fight back with a machete.
			player.inventory.add_item("machete", 1)
			_select("machete")
			_xp_before = int(main.get_node("Skills").xp["combat"])
			_next(3)
		3:
			if _target == null or not is_instance_valid(_target) or not _target.is_alive():
				_check(main.ruins["enemies"].kills >= 1, "the kill counted")
				_check(int(main.get_node("Skills").xp["combat"]) > _xp_before, "combat XP for the kill")
				_next(4)
				return false
			if ticks > 900:
				_check(false, "the machete never killed the enemy (hp %d)" % _target.hp)
				_next(4)
				return false
			player._iframes = 5.0  # keep the test about our swings, not about dodging
			player.global_position = _target.global_position + Vector2(-12, 0)
			player.facing = "east"
			player._mouse_aim_until = 0.0
			if not player.using_tool:
				player.use_tool()
		4:
			if ticks < 5:
				return false
			var objects: Node = main.ruins["objects"]
			var map: Node = main.ruins["map"]
			# Search the first container.
			var container_anchor := _first_anchor_with(func(kind: String) -> bool:
				return load("res://scripts/world_object_db.gd").container_of(kind) != "")
			_check(container_anchor != Vector2i(-1, -1), "the level has a container")
			if container_anchor != Vector2i(-1, -1):
				player.global_position = map.get_global_cell_center(container_anchor + Vector2i(0, 1))
				player.facing = "north"
				player.interact()
				_check(objects.is_opened(container_anchor), "the container was searched")
				_check(objects.instant_verb(container_anchor, "") == "", "nothing more to search there")
			# Stand by the rad barrel.
			var barrel := _first_anchor_with(func(kind: String) -> bool: return kind == "rad_barrel")
			if barrel != Vector2i(-1, -1):
				player.global_position = map.get_global_cell_center(barrel + Vector2i(0, 1))
				_hp_before = player.rads
			_next(5)
		5:
			if ticks < 90:
				return false
			_check(player.rads > _hp_before, "standing by a leaking drum irradiates (%.2f rads)" % player.rads)
			# Pick up and read the level's note.
			main.ruins["objects"].collect_all_pickups(player.inventory)
			_haul_item = "lore_note"
			_check(player.inventory.count_of("lore_note") >= 1, "picked up a lore note")
			_select("lore_note")
			player.interact()
			_check(main.confirm_ui.active, "the note opens in the reader")
			main.confirm_ui.choose(0)
			_check(main.expedition.notes_read.size() >= 1 or not ResourceLoader.exists("res://scripts/lore_db.gd"),
				"the note was recorded as read")
			# Down the stairs.
			_use_object("subway_stairs")
			_check(main.confirm_ui.active, "the stairs ask about going deeper")
			main.confirm_ui.choose(0)
			_next(6)
		6:
			if ticks < 45:
				return false
			_check(main.expedition.depth == 2, "depth 2 reached")
			_check(player.current_zone_id == "ruins", "still in the ruins")
			# Take something home: a stack of scrap counts as found out here.
			player.inventory.add_item("scrap_metal", 4)
			root.get_node("Events").item_gained.emit("scrap_metal", 4)
			_haul_before = player.inventory.count_of("scrap_metal")
			_use_object("kaels_truck")
			_check(main.confirm_ui.active, "the truck offers the ride home")
			main.confirm_ui.choose(0)
			_next(7)
		7:
			if ticks < 45:
				return false
			_check(not main.expedition.active, "the expedition ended")
			_check(player.current_zone_id == "path", "home at the north checkpoint")
			_check(player.inventory.count_of("scrap_metal") == _haul_before, "the haul came home")
			_check(main.expedition.max_depth == 2, "deepest level remembered")
			# Second run: this one goes badly.
			day_manager.minutes_into_day = 10 * 60.0
			main._bind_zone("path", Vector2i(11, 3))
			player.facing = "north"
			player.interact()
			main.confirm_ui.choose(0)
			_next(8)
		8:
			if ticks < 45:
				return false
			_check(main.expedition.active, "second expedition under way")
			player.inventory.add_item("copper_wire", 3)
			root.get_node("Events").item_gained.emit("copper_wire", 3)
			_haul_before = player.inventory.count_of("scrap_metal")
			_day_before = day_manager.day
			player._iframes = 0.0
			player.take_hit(9999, player.global_position + Vector2(10, 0), 10.0)
			_check(player.dead, "the player went down")
			_next(9)
		9:
			if ticks < 200:
				return false
			_check(not player.dead, "back on their feet")
			_check(player.current_zone_id == "farm", "woke up at home")
			_check(day_manager.day == _day_before + 1, "it's the next morning")
			_check(player.hp <= player.effective_max_hp() * 0.11 + 1.0, "woke at about 10%% HP (%.0f)" % player.hp)
			_check(player.inventory.count_of("copper_wire") == 0, "this run's copper wire was lost")
			_check(player.inventory.count_of("scrap_metal") == _haul_before, "the first run's haul is untouched")
			_check(not main.expedition.active, "the expedition is over")
			_check(main.confirm_ui.active, "the wake-up note is showing")
			main.confirm_ui.choose(0)
			_check(game_state.save_game(player, main.zones, main.get_node("Settlers"),
				main.get_node("Animals"), main.get_node("Affinity")), "saved")
			main.queue_free()
			main = null
			_next(10)
		10:
			if ticks < 3:
				return false
			game_state.load_save_from_disk()
			_boot()
			_next(11)
		11:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			_check(main.expedition.runs == 2, "two expeditions remembered (%d)" % main.expedition.runs)
			_check(main.expedition.max_depth == 2, "deepest level survives the reload")
			_check(main.expedition.gift_given, "Kael's loan isn't handed out twice")
			_check(main.zones["path"]["objects"].count_kinds(["kaels_truck"]) == 1, "exactly one truck after reload")
			_finish()
			return true
	return false


func _nearest_enemy() -> Node:
	var best: Node = null
	var best_d := INF
	for e in main.ruins["enemies"].live_enemies():
		var d: float = (e as Node2D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _first_anchor_with(pred: Callable) -> Vector2i:
	var all: Dictionary = main.ruins["objects"].all_objects()
	for anchor in all:
		if pred.call(String(all[anchor]["kind"])):
			return anchor
	return Vector2i(-1, -1)


## Stands south of the object's footprint (its bottom-left cell) facing north and interacts.
func _use_object(kind: String) -> void:
	var anchor := _first_anchor_with(func(k: String) -> bool: return k == kind)
	if anchor == Vector2i(-1, -1):
		_check(false, "no %s in the level" % kind)
		return
	var size: Vector2i = load("res://scripts/world_object_db.gd").size_of(kind)
	var map: Node = main.ruins["map"]
	player.global_position = map.get_global_cell_center(anchor + Vector2i(0, size.y))
	player.velocity = Vector2.ZERO
	player.facing = "north"
	player._mouse_aim_until = 0.0
	player.interact()


func _select(item_id: String) -> void:
	for i in player.inventory.TOTAL_SLOTS:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item_id:
			if i >= player.inventory.HOTBAR_SIZE:
				player.inventory.move_slot(i, player.inventory.HOTBAR_SIZE - 1)
				i = player.inventory.HOTBAR_SIZE - 1
			player.inventory.select_hotbar(i)
			return


func _wipe() -> void:
	var dir := ProjectSettings.globalize_path("user://expedition_smoke_saves")
	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)


func _finish() -> void:
	_wipe()
	if failures.is_empty():
		print("EXPEDITION SMOKE: all checks passed (ride out, AI hits, machete kill, search, rads, note, deeper, home with the haul, death penalty, save/reload).")
		quit(0)
	else:
		for f in failures:
			print("EXPEDITION SMOKE FAIL: " + f)
		quit(1)
