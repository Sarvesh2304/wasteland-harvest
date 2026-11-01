extends SceneTree
## Milestone B social + quests smoke (2026-10-08, docs/SOCIAL_AND_QUESTS.md): boots the real game
## (Forest Edge) and drives the new systems end to end through their real entry points.
##   1. A first meeting plays the intro tree; a second chat the same day is a repeat line; the day's
##      first chat earns friendship.
##   2. A gift: holding something giftable adds "Give the ..." to today's line; giving scores it and
##      remembers the taste; a second gift the same day is refused (and says so).
##   3. The notice board: the town square's board opens on Interact; accepting takes the notice; the
##      requester gets a "!" marker; talking to them with the goods hands it in and pays.
##   4. A hunt request finishes on its last kill.
##   5. Town Works: contributing through the board funds Marta's shopfront; overnight it's built
##      (the store's art changes, shipping pays 10% more, a notice explains). The clinic, the
##      watchtower and the greenhouse follow: Doc's tent comes down and her clinic heals you for
##      a fee, Kael offers every district reached, and the greenhouse grows out of season.
##   6. The JOURNAL and PEOPLE tabs fill in.
##   7. Save and reload: friendship, the board and every finished project survive.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/social_smoke.gd

const QuestDB := preload("res://scripts/quest_db.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const GreenhouseScript := preload("res://scripts/greenhouse.gd")

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _finished := false
var _refused: Array = []
var _marta_points := 0


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://social_smoke_saves"
	game_state.legacy_save_path = "user://social_smoke_saves/legacy.json"
	game_state.save_path = "user://social_smoke_saves/slot_1.json"
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("social_smoke_saves"):
		for f in DirAccess.get_files_at("user://social_smoke_saves"):
			DirAccess.remove_absolute("user://social_smoke_saves/" + f)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	stage = to_stage
	ticks = 0


## -- Helpers --

func _npc(id: String) -> Node:
	for zone_id in main.zones:
		for npc in main.zones[zone_id]["npcs"].npcs():
			if String(npc.npc_id) == id:
				return npc
	return null


func _talk(id: String) -> bool:
	return main.get_node("DialogueUI").open_dialogue(_npc(id))


func _press(ui: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui._unhandled_input(event)


func _release(ui: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	ui._unhandled_input(event)


## Reveal the current line and move on (Space twice).
func _advance() -> void:
	var dlg: Node = main.get_node("DialogueUI")
	_press(dlg, "use_tool")
	_press(dlg, "use_tool")


func _hold(item_id: String) -> void:
	var inv = player.inventory
	for i in inv.slots.size():
		if String(inv.get_slot(i).get("item_id", "")) == item_id:
			if i >= inv.HOTBAR_SIZE:
				inv.move_slot(i, inv.HOTBAR_SIZE - 1)
				i = inv.HOTBAR_SIZE - 1
			inv.select_hotbar(i)
			return


func _hold_tool() -> void:
	player.inventory.select_hotbar(0)


func _next_morning() -> void:
	day_manager.skip_to_next_morning()
	day_manager.minutes_into_day = 9 * 60.0


func _stock_for(project_id: String) -> void:
	var need := QuestDB.needs(project_id)
	for item in need:
		player.inventory.add_item(String(item), int(need[item]))
	player.set_credits(int(player.credits) + QuestDB.credits_needed(project_id))


func _close_notices() -> void:
	var confirm: Node = main.confirm_ui
	var guard := 0
	while confirm.active and guard < 8:
		confirm.choose(0)
		guard += 1


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if _finished:
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			day_manager.time_paused = true
			day_manager.minutes_into_day = 9 * 60.0
			main._bind_zone("town", Vector2i(16, 6))
			_check(not QuestDB.templates().is_empty(), "data/requests.json has templates")
			_check(QuestDB.project_ids().size() == 4, "four Town Works projects")
			_check(main.zones["town"]["structures"].has_works_building("doc_tent"), "Doc's tent stands on day 1")
			_check(main.town_works.greenhouse != null and not main.town_works.greenhouse.restored,
				"the old greenhouse stands ruined on the farm")
			_check(not main.quests.posted.is_empty(), "the board has a notice on day 1")
			_next(1)
		1:
			# -- First meeting vs. a second chat --
			var dlg: Node = main.get_node("DialogueUI")
			_hold_tool()
			_check(_talk("marta"), "talking to Marta opens the box")
			_check(dlg._node_id == DialogueDB.start_node_id("marta"), "the first chat is her intro tree")
			_check(main.affinity.points_for("marta") == AffinityScript.TALK_POINTS, "a chat earns friendship")
			_press(dlg, "ui_cancel")
			_check(_talk("marta"), "talk again")
			_check(dlg._node_id == "_line" and DialogueDB.repeat_lines("marta").has(dlg._full_text),
				"the second chat the same day is a repeat line")
			_check(main.affinity.points_for("marta") == AffinityScript.TALK_POINTS, "no second award today")
			_advance()
			_check(dlg._node_id == DialogueDB.service_node_id("marta"), "then her shop menu")
			_press(dlg, "ui_cancel")
			_next(2)
		2:
			# -- A gift on a new day --
			_next_morning()
			var dlg: Node = main.get_node("DialogueUI")
			dlg.gift_refused.connect(func(_n, reason): _refused.append(reason))
			player.inventory.add_item("glow_melon", 2)
			_hold("glow_melon")
			_marta_points = main.affinity.points_for("marta")
			_check(_talk("marta"), "talk with a melon in hand")
			_check(dlg._node_id == "_line", "a later chat opens on today's line")
			var choices: Array = dlg._available_choices()
			_check(choices.size() == 2 and String(choices[0]["text"]).contains("Glow Melon"),
				"holding something giftable offers it (%s)" % [choices])
			_press(dlg, "use_tool")  # reveal
			_press(dlg, "use_tool")  # choice 0: give
			_check(dlg._node_id == "_gift_reply", "she reacts to the gift")
			var reaction := String(main.affinity.known_gifts("marta").get("glow_melon", ""))
			_check(reaction != "", "the taste is remembered")
			_check(player.inventory.count_of("glow_melon") == 1, "one melon was handed over")
			_check(main.affinity.points_for("marta") == _marta_points + AffinityScript.TALK_POINTS
					+ AffinityScript.gift_points(reaction, false), "talk + gift points")
			_press(dlg, "ui_cancel")
			_check(_talk("marta"), "talk again, melon still in hand")
			_check(dlg._available_choices().is_empty() or not String(dlg._available_choices()[0]["text"]).begins_with("Give"),
				"no second gift today")
			_check(_refused.has("today"), "and the game says why")
			_press(dlg, "ui_cancel")
			_hold_tool()
			_next(3)
		3:
			# -- The notice board through the real interaction --
			var deliver := {}
			for t in QuestDB.templates():
				if String(t["kind"]) == "deliver" and t.has("pool") and String(t["npc"]) != "rancher_silas" \
						and not QuestDB.pool_items(String(t["pool"]), day_manager.season()).is_empty() \
						and int(t.get("min_runs", 0)) == 0:
					deliver = t
					break
			_check(not deliver.is_empty(), "a town delivery template exists")
			var item: String = QuestDB.pool_items(String(deliver["pool"]), day_manager.season())[0]
			main.quests.posted = {"template": String(deliver["id"]), "npc": String(deliver["npc"]), "kind": "deliver",
				"item": item, "count": 2, "posted_day": day_manager.day, "reward": QuestDB.delivery_reward(item, 2)}
			var town_map: Node2D = main.zones["town"]["map"]
			player.global_position = town_map.get_global_cell_center(Vector2i(17, 5))
			player.velocity = Vector2.ZERO
			player.facing = "north"
			_next(4)
		4:
			if ticks < 3:
				return false
			var notice: Node = main.notice_ui
			player.interact()
			_check(notice.active, "Interact on the board opens it")
			_release(notice, "interact")
			_press(notice, "interact")  # row 0: accept
			_check(not main.quests.active.is_empty(), "the request was accepted from the board")
			var npc_id := String(main.quests.active["npc"])
			_check(_npc(npc_id).has_quest_marker(), "%s shows a '!'" % npc_id)
			_press(notice, "ui_cancel")
			_check(not notice.active, "Esc closes the board")
			# Hand it in.
			var item := String(main.quests.active["item"])
			var reward := int(main.quests.active["reward"])
			player.inventory.add_item(item, 2)
			var credits_before := int(player.credits)
			var points_before: int = main.affinity.points_for(npc_id)
			var thanks := QuestDB.text_for(main.quests.active, "thanks")
			_check(_talk(npc_id), "talk to the requester")
			var dlg: Node = main.get_node("DialogueUI")
			if dlg._node_id != "_line":
				# A first meeting plays the intro; hand it in on the next chat.
				_press(dlg, "ui_cancel")
				_check(_talk(npc_id), "talk to the requester again")
			_check(dlg._full_text == thanks, "they thank you with the request's line")
			_check(int(player.credits) == credits_before + reward, "paid %d Cr" % reward)
			_check(main.affinity.points_for(npc_id) >= points_before + AffinityScript.REQUEST_POINTS,
				"+150 friendship for the request")
			_check(main.quests.active.is_empty() and main.quests.requests_done == 1, "the request is done")
			_check(not _npc(npc_id).has_quest_marker(), "the '!' is gone")
			_press(dlg, "ui_cancel")
			_next(5)
		5:
			# -- A hunt finishes on its last kill --
			var hunt := {}
			for t in QuestDB.templates():
				if String(t["kind"]) == "hunt":
					hunt = t
					break
			_check(not hunt.is_empty(), "a hunt template exists")
			var enemy := String(hunt.get("enemy", "any"))
			main.quests.posted = {"template": String(hunt["id"]), "npc": String(hunt["npc"]), "kind": "hunt",
				"enemy": enemy, "count": 2, "posted_day": day_manager.day, "reward": 2 * QuestDB.HUNT_REWARD_PER_KILL}
			main.quests.accept(day_manager.day)
			var credits_before := int(player.credits)
			var kill_type := "shambler" if enemy == "any" else enemy
			main.ruins["enemies"].enemy_killed.emit(kill_type)
			main.ruins["enemies"].enemy_killed.emit(kill_type)
			_check(main.quests.active.is_empty(), "two kills finish the hunt")
			_check(int(player.credits) == credits_before + 2 * QuestDB.HUNT_REWARD_PER_KILL, "the hunt paid")
			_next(6)
		6:
			# -- Town Works through the board: Marta's shopfront --
			_stock_for("shop_expansion")
			var notice: Node = main.notice_ui
			_check(notice.open(), "the board opens")
			_release(notice, "use_tool")
			_press(notice, "move_down")  # row 1: the first project
			_check(notice._cursor == 1, "the cursor is on the first project")
			_press(notice, "use_tool")
			_check(main.quests.is_funded("shop_expansion"), "contributing everything funds it")
			_press(notice, "ui_cancel")
			_check(main.zones["town"]["structures"].building_kind("store") == "store", "not built yet")
			_next_morning()
			_next(7)
		7:
			if ticks < 3:
				return false
			var town: Node = main.zones["town"]["structures"]
			_check(main.quests.is_finished("shop_expansion"), "built overnight")
			_check(town.building_kind("store") == "store_expanded", "the store has its new shopfront")
			_check(is_equal_approx(town.sale_multiplier, 1.1) and is_equal_approx(main.zones["farm"]["structures"].sale_multiplier, 1.1),
				"shipping pays 10% more")
			_check(main.confirm_ui.active, "a notice explains what changed")
			_close_notices()
			# The clinic, the watchtower and the greenhouse, funded directly.
			for id in ["clinic", "watchtower", "greenhouse"]:
				_stock_for(id)
				main.quests.contribute(id, player, day_manager.day)
				_check(main.quests.is_funded(id), "%s funded" % id)
			# Meet Doc today, so tomorrow's chat is her daily line and clinic.
			_talk("doc_ama")
			_press(main.get_node("DialogueUI"), "ui_cancel")
			_next_morning()
			_next(8)
		8:
			if ticks < 3:
				return false
			_close_notices()
			var town: Node = main.zones["town"]["structures"]
			_check(town.building_kind("clinic") == "town_clinic", "the clinic is rebuilt")
			_check(not town.has_works_building("doc_tent"), "Doc's tent is gone")
			_check(town.has_works_building("watchtower"), "the watchtower stands by the west gate")
			_check(main.zones["town"]["map"].is_blocked_at(Vector2i(1, 1)), "the watchtower is solid")
			var gh: Node = main.town_works.greenhouse
			_check(gh.restored, "the greenhouse is rebuilt")
			var farm: Node = main.zones["farm"]["farm"]
			_check(farm.greenhouse_cells.size() == 24, "a 6x4 plot under glass")
			var wall: Vector2i = GreenhouseScript.wall_cells(gh.top_left)[0]
			_check(main.zones["farm"]["map"].is_blocked_at(wall), "the greenhouse walls are solid")
			# Out of season inside, not outside.
			var inside: Vector2i = GreenhouseScript.interior_cells(gh.top_left)[0]
			var off_season := "frostroot" if day_manager.season() != "winter" else "rain_radish"
			_check(farm.till(inside), "the greenhouse soil tills")
			_check(farm.plant_check(inside, off_season) == "", "%s can be planted in the greenhouse" % off_season)
			farm.plant(inside, off_season)
			farm.water(inside)
			_next_morning()
			_check(not farm.is_dead(inside), "and it keeps growing out of season")
			_check(int(farm.get_plot(inside).get("growth", 0)) >= 1, "it grew overnight")
			# Doc's clinic: hurt, pay, healed.
			_close_notices()
			player.set_hp(10.0)
			player.set_credits(500)
			var dlg: Node = main.get_node("DialogueUI")
			_check(_talk("doc_ama"), "talk to Doc")
			_check(dlg._node_id == "_line", "today's line first")
			_advance()
			_check(dlg._node_id == "clinic", "then the clinic menu (the clinic is open)")
			_press(dlg, "use_tool")  # reveal
			_press(dlg, "use_tool")  # choice 0: patch me up
			_check(not dlg.active, "the heal closes the conversation")
			_check(is_equal_approx(player.hp, player.effective_max_hp()), "Doc healed you to full")
			_check(int(player.credits) == 500 - 80, "for 80 Cr")
			# Kael's routes from the watchtower.
			main.expedition.max_depth = 3
			main._on_vehicle_used("path")
			_check(main.confirm_ui.active and main.confirm_ui._choice_labels.size() == 4,
				"Kael offers the three districts reached, plus Not yet")
			main.confirm_ui.choose(3)
			_next(9)
		9:
			# -- The menu's JOURNAL and PEOPLE tabs --
			var menu: Node = main.get_node("MenuScreen")
			menu.open_menu()
			menu.tab_index = menu.TAB_JOURNAL
			menu._refresh()
			_check(menu._journal_tab.visible and menu._journal_tab.get_child_count() > 5, "the journal fills in")
			menu.tab_index = menu.TAB_PEOPLE
			menu._refresh()
			_check(menu._people_tab.get_child_count() >= AffinityScript.NAMED_NPC_IDS.size() * 3, "everyone is on the people tab")
			menu.close()
			# -- Save and reload --
			_marta_points = main.affinity.points_for("marta")
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
			var town: Node = main.zones["town"]["structures"]
			_check(main.affinity.points_for("marta") == _marta_points, "friendship survives the reload")
			_check(main.affinity.known_gifts("marta").has("glow_melon"), "so do discovered tastes")
			_check(main.quests.requests_done == 2, "and the requests done")
			for id in QuestDB.project_ids():
				_check(main.quests.is_finished(id), "%s is still finished" % id)
			_check(town.building_kind("store") == "store_expanded", "the shopfront is still there")
			_check(town.building_kind("clinic") == "town_clinic" and not town.has_works_building("doc_tent"),
				"so is the clinic")
			_check(town.has_works_building("watchtower"), "and the watchtower")
			_check(main.town_works.greenhouse.restored, "and the greenhouse")
			_check(main.zones["farm"]["farm"].greenhouse_cells.size() == 24, "still growing anything")
			_finish()
			return true
	return false


func _finish() -> void:
	_finished = true
	_wipe()
	if failures.is_empty():
		print("SOCIAL SMOKE: all checks passed (intro/repeat, gift + refusal, board accept, hand-in, hunt, four Town Works projects and their changes, clinic heal, Kael's routes, greenhouse out of season, journal/people, save/reload).")
		quit(0)
	else:
		for f in failures:
			print("SOCIAL SMOKE FAIL: %s" % f)
		quit(1)


func _finalize() -> void:
	if not _finished:
		print("SOCIAL SMOKE FAIL: the run ended at stage %d before finishing" % stage)
		for f in failures:
			print("SOCIAL SMOKE FAIL: %s" % f)
