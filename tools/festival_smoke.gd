extends SceneTree
## Milestone D festival smoke (docs/LIVING_SETTLEMENT.md §4): boots the real game (Forest Edge)
## and plays a year of festivals through the real booth, confirm prompts and dialogue box.
##   1. Spring 13: tomorrow's festival is a dialogue flag. Spring 14 (Planting Day): the square is
##      dressed, everyone gathers at nine, the booth starts the seed hunt, twelve packets appear,
##      ten are picked, the hunt ends on the clock and pays the top prize. At six they go home.
##   2. The next morning the square is cleared.
##   3. Summer 15 (Scorch Fair): three goat races through the booth, each paying (or not) by the
##      odds; a fourth is refused.
##   4. Autumn 21 (Harvest Day): the best five things in the pack go on the table, and the place
##      the rules give pays its prize; the player keeps the things.
##   5. Winter 7: a name is drawn. Winter 14 (Winter Gathering): a gift to that person through the
##      real dialogue counts five times; the parcel at the booth holds the giver's gift.
##   6. Save and reload: what was done at each festival this year survives.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/festival_smoke.gd

const FestivalDB := preload("res://scripts/festival_db.gd")
## Loaded once the game is up (festivals.gd names the DayManager autoload, which a SceneTree
## script's preload can't see yet).
var FestivalsScript: GDScript = null
const Calendar := preload("res://scripts/calendar.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const ItemDB := preload("res://scripts/item_db.gd")

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _finished := false
var _credits := 0
var _race := 0
var _circle: Dictionary = {}
var _done: Dictionary = {}


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://festival_smoke_saves"
	game_state.legacy_save_path = "user://festival_smoke_saves/legacy.json"
	game_state.save_path = "user://festival_smoke_saves/slot_1.json"
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("festival_smoke_saves"):
		for f in DirAccess.get_files_at("user://festival_smoke_saves"):
			DirAccess.remove_absolute("user://festival_smoke_saves/" + f)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	print("[festival smoke] stage %d (day %d)" % [to_stage, day_manager.day])
	stage = to_stage
	ticks = 0


func _press(ui: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui._unhandled_input(event)


func _close_popups() -> void:
	var guard := 0
	while main.confirm_ui.active and guard < 10:
		guard += 1
		main.confirm_ui.choose(0)
	var dlg: Node = main.get_node("DialogueUI")
	if dlg.active:
		dlg.close()


func _next_morning() -> void:
	_close_popups()
	day_manager.skip_to_next_morning()
	day_manager.minutes_into_day = 8 * 60.0
	_close_popups()


func _go_to(season: String, dom: int) -> void:
	var target := Calendar.absolute_day(1, season, dom)
	while day_manager.day < target:
		_next_morning()


func _town() -> Dictionary:
	return main.zones["town"]


func _booth() -> void:
	player.works_used.emit(FestivalsScript.BOOTH_ID)


func _hold(item_id: String) -> void:
	var inv = player.inventory
	for i in inv.slots.size():
		if String(inv.get_slot(i).get("item_id", "")) == item_id:
			if i >= inv.HOTBAR_SIZE:
				inv.move_slot(i, inv.HOTBAR_SIZE - 1)
				i = inv.HOTBAR_SIZE - 1
			inv.select_hotbar(i)
			return


func _npc(id: String) -> Node:
	for zone_id in ["town", "ranch"]:
		var npc: Node = main.zones[zone_id]["npcs"].npc_by_id(id)
		if npc != null and npc.visible:
			return npc
	return null


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if _finished:
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			FestivalsScript = load("res://scripts/festivals.gd")
			_check(main.festivals != null and main.get_node("MenuScreen").festivals == main.festivals,
				"the festivals node is wired to the journal")
			_check(main.festivals.today().is_empty(), "no festival on day 1")
			var next: Dictionary = main.festivals.next_festival(1)
			_check(String(next.get("id", "")) == "planting_day" and int(next.get("in_days", -1)) == 13,
				"the next one is Planting Day, in 13 days (%s)" % [next])
			# -- Planting Day --
			_go_to("spring", 13)
			_check(main.dialogue_context()["flags"].has("festival_tomorrow"), "the town knows it's tomorrow")
			_next_morning()
			_check(main.festivals.is_dressed(), "the square is dressed on Spring 14")
			_check(main.dialogue_context()["flags"].has("festival_planting_day"), "festival_planting_day flag")
			var structures: Node = _town()["structures"]
			_check(structures.works_id_at(FestivalsScript.BOOTH_CELL) == FestivalsScript.BOOTH_ID, "the booth stands")
			_check(_town()["map"].get_node("Props").has_temp(FestivalsScript.DRESS_TAG), "bunting and lanterns are up")
			day_manager.minutes_into_day = 9 * 60.0
			_next(1)
		1:
			if ticks < 3:
				return false
			var harlan: Node = _town()["npcs"].npc_by_id("mayor_harlan")
			_check(harlan != null and harlan.gather_cell == FestivalsScript.SPOTS["mayor_harlan"],
				"Harlan heads for his spot in the square")
			var silas: Node = _town()["npcs"].npc_by_id("rancher_silas")
			_check(silas != null and silas.gather_cell == FestivalsScript.SPOTS["rancher_silas"],
				"Silas comes in from the ranch")
			_credits = int(player.credits)
			_booth()
			_check(main.confirm_ui.active, "the booth asks to start the hunt")
			main.confirm_ui.choose(0)
			var objects: Node = _town()["objects"]
			_check(objects.count_kinds([FestivalsScript.PACKET_KIND]) == FestivalDB.HUNT_PACKETS,
				"twelve packets hidden (%d)" % objects.count_kinds([FestivalsScript.PACKET_KIND]))
			var picked := 0
			var all: Dictionary = objects.all_objects()
			for anchor in all.keys():
				if picked < 10 and String(all[anchor]["kind"]) == FestivalsScript.PACKET_KIND:
					if not objects.pick(anchor, player.inventory).is_empty():
						picked += 1
			_check(picked == 10, "picked ten (%d)" % picked)
			_booth()
			_check(main.confirm_ui.active and String(main.confirm_ui._body.text).contains("10 so far"),
				"the booth keeps count")
			main.confirm_ui.choose(0)
			day_manager.minutes_into_day = 11 * 60.0 + 30.0
			_next(2)
		2:
			if ticks < 3:
				return false
			_check(main.confirm_ui.active, "the hunt ends on the clock with a result")
			_close_popups()
			var key := FestivalDB.key("planting_day", day_manager.day)
			_check(int(main.festivals.done.get(key, -1)) == 10, "ten found, remembered (%s)" % [main.festivals.done])
			_check(int(player.credits) - _credits == 300, "the top prize: 300 Cr (%d)" % (int(player.credits) - _credits))
			_check(player.inventory.count_of("seed_glow_melon") >= 3, "and three Glow Melon Seeds")
			_check(_town()["objects"].count_kinds([FestivalsScript.PACKET_KIND]) == 0, "the last two are cleared away")
			_booth()
			_check(main.confirm_ui.active and String(main.confirm_ui._body.text).contains("over"), "no second hunt")
			_close_popups()
			day_manager.minutes_into_day = 18 * 60.0 + 5.0
			_next(3)
		3:
			if ticks < 3:
				return false
			var harlan: Node = _town()["npcs"].npc_by_id("mayor_harlan")
			_check(harlan.gather_cell == harlan.NO_GATHER, "at six everyone goes home")
			_check(_town()["npcs"].npc_by_id("rancher_silas") == null, "Silas's stand-in has left town")
			_next_morning()
			_check(not main.festivals.is_dressed(), "the square is cleared the next morning")
			_check(_town()["structures"].works_id_at(FestivalsScript.BOOTH_CELL) == "", "no booth")
			_check(not _town()["map"].get_node("Props").has_temp(FestivalsScript.DRESS_TAG), "no bunting")
			# -- Scorch Fair --
			_go_to("summer", 15)
			_check(main.dialogue_context()["flags"].has("festival_scorch_fair"), "Scorch Fair today")
			main.festivals.race_seconds = 0.1
			player.set_credits(1000)
			_race = 0
			_next(4)
		4:
			# One race per pass: bet on Pickles (the long shot) at the booth, watch, read the result.
			if _race < FestivalDB.RACES_PER_DAY:
				if ticks == 1:
					_credits = int(player.credits)
					_booth()
					_check(main.confirm_ui.active, "race %d: the booth takes bets" % (_race + 1))
					main.confirm_ui.choose(3)
					_check(player.watching, "the player watches the race")
					_check(int(player.credits) == _credits - FestivalDB.RACE_STAKE, "the stake is paid")
				elif ticks > 40:
					_check(not player.watching and main.confirm_ui.active, "race %d finished" % (_race + 1))
					var won := String(main.confirm_ui._body.text).contains("You win")
					var expect := _credits - FestivalDB.RACE_STAKE + (FestivalDB.race_payout(6) if won else 0)
					_check(int(player.credits) == expect, "race %d pays by the odds (%d, expected %d)" % [_race + 1,
						int(player.credits), expect])
					_close_popups()
					_race += 1
					ticks = 0
				return false
			_booth()
			_check(main.confirm_ui.active and String(main.confirm_ui._body.text).contains("done for the day"),
				"no fourth race")
			_close_popups()
			# -- Harvest Day --
			_go_to("autumn", 21)
			_check(main.dialogue_context()["flags"].has("festival_harvest_day"), "Harvest Day today")
			for item in ["glow_melon", "ironroot", "cheese", "pumpkin_soup", "honey", "wild_greens"]:
				player.inventory.add_item(item, 1)
			var have := {}
			for slot in player.inventory.slots:
				var id := String((slot as Dictionary).get("item_id", ""))
				if id != "":
					have[id] = int(have.get(id, 0)) + int((slot as Dictionary).get("count", 0))
			var entry := FestivalDB.show_entry(have)
			var place := FestivalDB.show_place(int(entry["score"]), 1)
			_credits = int(player.credits)
			_booth()
			_check(main.confirm_ui.active and String(main.confirm_ui._body.text).contains("Your table"), "the table is laid out")
			main.confirm_ui.choose(0)
			_check(int(main.festivals.done.get(FestivalDB.key("harvest_day", day_manager.day), 0)) == place,
				"placed %d" % place)
			_check(int(player.credits) - _credits == int(FestivalDB.SHOW_PRIZES[place]), "and paid the prize")
			_check(player.inventory.count_of("glow_melon") >= 1, "the things stay in the pack")
			_close_popups()
			# -- Winter Gathering --
			_go_to("winter", 7)
			_circle = main.festivals.circle.duplicate()
			_check(_circle.has("friend") and _circle.has("giver") and _circle["friend"] != _circle["giver"],
				"names drawn on Winter 7 (%s)" % [_circle])
			_go_to("winter", 14)
			day_manager.minutes_into_day = 9 * 60.0
			_next(5)
		5:
			if ticks < 3:
				return false
			var friend := String(_circle["friend"])
			var npc := _npc(friend)
			_check(npc != null, "%s is at the gathering" % friend)
			if npc == null:
				_finish()
				return true
			var dlg: Node = main.get_node("DialogueUI")
			# The first chat ever is the intro; the gift is offered on the next.
			_check(dlg._is_circle_gift(friend), "the dialogue box knows the circle gift")
			player.inventory.add_item("cooked_meal", 2)
			_hold("cooked_meal")
			var before := int(main.affinity.points_for(friend))
			var gift_offered := false
			for attempt in 2:
				_check(dlg.open_dialogue(npc), "talk to %s" % friend)
				var choices: Array = dlg._available_choices()
				if not choices.is_empty() and String(choices[0].get("text", "")).begins_with("Give"):
					gift_offered = true
					_press(dlg, "use_tool")
					_press(dlg, "use_tool")
					break
				dlg.close()
			_check(gift_offered, "the gift is offered")
			var reaction := String(main.affinity.known_gifts(friend).get("cooked_meal", ""))
			var gained := int(main.affinity.points_for(friend)) - before
			_check(reaction != "" and gained >= AffinityScript.gift_points(reaction, true),
				"it counts five times (%d points for a %s gift)" % [gained, reaction])
			_check(bool(main.festivals.circle.get("given", false)), "the circle gift is marked given")
			_close_popups()
			var giver := String(_circle["giver"])
			var gift_item := String((FestivalDB.festival("winter_gathering").get("gifts", {}) as Dictionary).get(giver, ""))
			var had := int(player.inventory.count_of(gift_item))
			_booth()
			_check(main.confirm_ui.active, "the booth has a parcel")
			main.confirm_ui.choose(0)
			_check(ItemDB.has_item(gift_item) and int(player.inventory.count_of(gift_item)) == had + 1,
				"the parcel holds %s's gift (%s)" % [giver, gift_item])
			_close_popups()
			_done = main.festivals.done.duplicate()
			_circle = main.festivals.circle.duplicate()
			_check(game_state.save_game(player, main.zones, main.get_node("Settlers"),
				main.get_node("Animals"), main.get_node("Affinity")), "saved")
			main.queue_free()
			main = null
			_next(6)
		6:
			if ticks < 3:
				return false
			game_state.load_save_from_disk()
			_boot()
			_next(7)
		7:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			_check(main.festivals.done == _done, "the year's results survive a reload (%s)" % [main.festivals.done])
			_check(main.festivals.circle == _circle, "so does the gift circle")
			_check(main.festivals.is_dressed(), "the square is dressed again on load")
			_finish()
			return true
	return false


func _finish() -> void:
	_finished = true
	_wipe()
	if failures.is_empty():
		print("FESTIVAL SMOKE: all checks passed (Planting Day hunt, clear-up, Scorch Fair races, Harvest Day show, Winter Gathering circle gift and parcel, save/reload).")
		quit(0)
	else:
		for f in failures:
			print("FESTIVAL SMOKE FAIL: %s" % f)
		quit(1)


func _finalize() -> void:
	if not _finished:
		print("FESTIVAL SMOKE FAIL: the run ended at stage %d before finishing" % stage)
		for f in failures:
			print("FESTIVAL SMOKE FAIL: %s" % f)
