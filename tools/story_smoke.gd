extends SceneTree
## Milestone D story smoke, The Signal (docs/LIVING_SETTLEMENT.md §5): boots the real game (Forest
## Edge) and plays the main story start to finish through the real dialogue box, the ruins, the
## vault door and the morning notices.
##   1. Day 8, one expedition done: the morning notice starts it; Harlan has a "!"; talking to him
##      plays story_static, and he wants three Radio Parts.
##   2. Every ruins level holds a Radio Part until he has them. One part: he keeps it ("have
##      some"). Three: story_parts, and that night the antenna goes up; the morning brings the
##      broadcast, and the hunt for the vault.
##   3. The Core: the vault door wants a Keycard, then the code (the Foreman's Letter), then opens
##      on three pages and gives the seed stock.
##   4. Harlan: story_decision, "Plant it here" -> done_home and story_home_end; harvests can yield
##      more; Monday brings his share; the flags and the journal follow.
##   5. Save and reload keeps the story and its effects; "Send it down the road" (done_shared)
##      gives Tully four days a week, more stock and longer demand lists.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/story_smoke.gd

const Calendar := preload("res://scripts/calendar.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var story: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _finished := false
var _notices_seen: Array = []


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://story_smoke_saves"
	game_state.legacy_save_path = "user://story_smoke_saves/legacy.json"
	game_state.save_path = "user://story_smoke_saves/slot_1.json"
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("story_smoke_saves"):
		for f in DirAccess.get_files_at("user://story_smoke_saves"):
			DirAccess.remove_absolute("user://story_smoke_saves/" + f)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	print("[story smoke] stage %d (day %d, story %s)" % [to_stage, day_manager.day, story.stage if story else "-"])
	stage = to_stage
	ticks = 0


func _press(ui: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui._unhandled_input(event)


func _dlg() -> Node:
	return main.get_node("DialogueUI")


func _close_popups() -> void:
	var guard := 0
	while main.confirm_ui.active and guard < 10:
		guard += 1
		main.confirm_ui.choose(0)
	if _dlg().active:
		_dlg().close()


## Mornings come with notices (main._notices); they're read here so the queue can't pile up.
func _next_morning() -> void:
	_close_popups()
	day_manager.skip_to_next_morning()
	day_manager.minutes_into_day = 9 * 60.0
	for notice in main._notices:
		_notices_seen.append(String(notice[0]))
	main._notices.clear()
	_close_popups()


func _harlan() -> Node:
	return main.zones["town"]["npcs"].npc_by_id("mayor_harlan")


## Walks a conversation forward, always taking choice `pick` when there is one, until it closes
## or reaches `stop_at`. Returns the node ids visited.
func _walk(pick: int = 0, stop_at: String = "") -> Array:
	var dlg := _dlg()
	var seen: Array = []
	var guard := 0
	while dlg.active and guard < 30:
		guard += 1
		seen.append(String(dlg._node_id))
		if String(dlg._node_id) == stop_at:
			break
		_press(dlg, "use_tool")  # reveal
		var choices: Array = dlg._available_choices()
		for i in mini(pick, maxi(choices.size() - 1, 0)):
			_press(dlg, "move_down")
		_press(dlg, "use_tool")
	return seen


func _crop_total() -> int:
	var total := 0
	for slot in player.inventory.slots:
		var id := String((slot as Dictionary).get("item_id", ""))
		if id != "" and main.ItemDB.item_type(id) == "crop":
			total += int((slot as Dictionary).get("count", 0))
	return total


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if _finished:
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			story = main.story
			_check(story != null and main.get_node("MenuScreen").story == story, "the story is wired to the journal")
			day_manager.minutes_into_day = 9 * 60.0
			# Meet Harlan on day 1 (the intro), so later chats are ordinary ones.
			_check(_dlg().open_dialogue(_harlan()), "meet Harlan")
			_walk()
			_close_popups()
			while day_manager.day < 8:
				_next_morning()
			_check(story.stage == "", "no story without an expedition yet (%s)" % story.stage)
			main.expedition.runs = 1
			_next_morning()
			_check(story.stage == "static", "day 9, one run done: it starts (%s)" % story.stage)
			_check(_notices_seen.has(String(story.stage_data("static")["title"])), "with a morning notice (%s)" % [_notices_seen])
			_check(main.dialogue_context()["flags"].has("story_signal"), "story_signal flag")
			_check(story.wants_talk("mayor_harlan") and _harlan().has_method("set_quest_marker"), "Harlan has a !")
			_check(_dlg().open_dialogue(_harlan()) and String(_dlg()._node_id) == "story_static",
				"talking to him plays story_static (%s)" % _dlg()._node_id)
			var seen := _walk()
			_check(not _dlg().active, "the conversation ends (%s)" % [seen])
			_check(story.stage == "radio_parts", "he wants Radio Parts (%s)" % story.stage)
			_check(String(story.journal_entry().get("journal", "")).contains("0 of 3"), "the journal counts them")
			main.expedition.depart(1)
			_next(1)
		1:
			if ticks < 30:
				return false
			var had: int = player.inventory.count_of("radio_part")
			main.ruins["objects"].collect_all_pickups(player.inventory)
			_check(player.inventory.count_of("radio_part") >= had + 1, "a Radio Part lies in the level")
			main.expedition.extract()
			_next(2)
		2:
			if ticks < 30:
				return false
			_close_popups()
			_check(player.current_zone_id != "ruins", "home again")
			var parts: int = player.inventory.count_of("radio_part")
			_check(_dlg().open_dialogue(_harlan()) and String(_dlg()._node_id) == "_story", "with one part: his have-some line")
			_walk()
			_check(story.parts_given == parts and player.inventory.count_of("radio_part") == 0, "he keeps it (%d)" % story.parts_given)
			player.inventory.add_item("radio_part", 3 - story.parts_given)
			_check(_dlg().open_dialogue(_harlan()) and String(_dlg()._node_id) == "story_parts", "three: story_parts")
			_walk()
			_check(story.antenna_pending and story.parts_given == 3, "the antenna goes up tonight")
			_check(not story.wants_talk("mayor_harlan"), "his ! is gone")
			_next_morning()
			_check(story.stage == "find_vault", "the broadcast morning: find the vault (%s)" % story.stage)
			_check(_notices_seen.has(String(story.stage_data("broadcast")["title"])), "the broadcast notice")
			_check(main.dialogue_context()["flags"].has("story_broadcast"), "story_broadcast flag")
			if ResourceLoader.exists("res://art/buildings/mayor_house_antenna.png"):
				var found := false
				for id in main.zones["town"]["structures"]._layout_visuals:
					var v = main.zones["town"]["structures"]._layout_visuals[id]
					if v is Sprite2D and (v as Sprite2D).texture.resource_path.ends_with("mayor_house_antenna.png"):
						found = true
				_check(found, "the antenna is on Harlan's roof")
			main.expedition.max_depth = 4
			main.expedition.depart(4)
			_next(3)
		3:
			if ticks < 30:
				return false
			var anchor: Vector2i = story._vault_anchor
			_check(anchor.x >= 0, "the vault door is in The Core")
			if anchor.x < 0:
				_finish()
				return true
			var objects: Node = main.ruins["objects"]
			_check(objects.instant_verb(anchor, "") == "Open", "it says Open")
			player.inventory.remove_item("keycard", player.inventory.count_of("keycard"))
			objects.interact_placed(anchor, player)
			_check(main.confirm_ui.active and main.confirm_ui._body.text == String(story.stage_data("find_vault")["need_keycard"]),
				"no keycard: the slot is dark")
			_close_popups()
			player.inventory.add_item("keycard", 1)
			objects.interact_placed(anchor, player)
			_check(main.confirm_ui.active and main.confirm_ui._body.text == String(story.stage_data("find_vault")["need_code"]),
				"a keycard but no code")
			_close_popups()
			main.expedition.notes_read.append("seed_vault")
			objects.interact_placed(anchor, player)
			_check(main.confirm_ui.active and main.confirm_ui._choice_labels[0].contains("4-1-7-7"), "the code, from the Foreman's Letter")
			main.confirm_ui.choose(0)
			var pages := 0
			while main.confirm_ui.active and pages < 5:
				pages += 1
				main.confirm_ui.choose(0)
			_check(pages == 3, "three pages (%d)" % pages)
			_check(story.stage == "decision" and player.inventory.count_of("vault_seeds") == 1, "the seed stock")
			_check(player.inventory.count_of("keycard") == 0, "the keycard stays in the slot")
			_check(main.dialogue_context()["flags"].has("story_vault_open"), "story_vault_open flag")
			main.expedition.extract()
			_next(4)
		4:
			if ticks < 30:
				return false
			_close_popups()
			_check(story.wants_talk("mayor_harlan"), "Harlan wants the seed")
			_check(_dlg().open_dialogue(_harlan()) and String(_dlg()._node_id) == "story_decision", "story_decision")
			var seen := _walk(0, "story_home_end")
			_check(story.stage == "done_home", "Plant it here: done_home (%s, %s)" % [story.stage, seen])
			_check(_dlg().active and String(_dlg()._node_id) == "story_home_end", "and he says so (%s)" % _dlg()._node_id)
			_walk()
			_check(player.inventory.count_of("vault_seeds") == 0, "he has the seed")
			_check(main.dialogue_context()["flags"].has("story_home"), "story_home flag")
			_check(is_equal_approx(main.zones["farm"]["farm"].vault_extra_chance, story.HOME_EXTRA_CHANCE), "harvests can yield more")
			_next_morning()
			_check(_notices_seen.has(String(story.stage_data("done_home")["title"])), "the morning-after notice")
			# Monday: Harlan's share of the town harvest.
			while Calendar.weekday(day_manager.day + 1) != "Mon":
				_next_morning()
			var before := _crop_total()
			_next_morning()
			_check(_crop_total() >= before + story.HOME_SHARE_EACH, "Monday brings Harlan's share (%d -> %d)" % [before, _crop_total()])
			_check(String(story.journal_entry()["title"]) == String(story.stage_data("done_home")["title"]), "the journal")
			_check((story.journal_entry()["past"] as Array).size() >= 4, "and what came before (%s)" % [story.journal_entry()["past"]])
			_check(game_state.save_game(player, main.zones, main.get_node("Settlers"),
				main.get_node("Animals"), main.get_node("Affinity")), "saved")
			main.queue_free()
			main = null
			_next(5)
		5:
			if ticks < 3:
				return false
			game_state.load_save_from_disk()
			_boot()
			_next(6)
		6:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			story = main.story
			_check(story.stage == "done_home", "the story survives a reload (%s)" % story.stage)
			_check(is_equal_approx(main.zones["farm"]["farm"].vault_extra_chance, story.HOME_EXTRA_CHANCE), "and its effect")
			# The other road.
			story.load_state({"stage": "done_shared"})
			story.apply_effects()
			_check(main.caravan.weekdays().size() == 4, "Tully comes four days a week (%s)" % [main.caravan.weekdays()])
			_check(main.caravan.extra_offers == story.SHARED_EXTRA_OFFERS, "with more stock")
			_check(main.market.demand_count == story.SHARED_DEMAND_COUNT, "and Marta wants more")
			_check(main.dialogue_context()["flags"].has("story_shared"), "story_shared flag")
			_finish()
			return true
	return false


func _finish() -> void:
	_finished = true
	_wipe()
	if failures.is_empty():
		print("STORY SMOKE: all checks passed (start notice, story_static, Radio Parts in the ruins, antenna and broadcast, vault door keycard/code/pages, decision, effects, save/reload, the shared road).")
		quit(0)
	else:
		for f in failures:
			print("STORY SMOKE FAIL: %s" % f)
		quit(1)


func _finalize() -> void:
	if not _finished:
		print("STORY SMOKE FAIL: the run ended at stage %d before finishing" % stage)
		for f in failures:
			print("STORY SMOKE FAIL: %s" % f)
