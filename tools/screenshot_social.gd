extends SceneTree
## Screenshots of Milestone B's social layer (2026-10-08): the notice board (a request, then a
## Town Works project), a gift offered and received, the JOURNAL and PEOPLE tabs, and the town and
## the farm greenhouse once every Town Works project is finished. 4x nearest-neighbour from the
## native 320x192.
## Run: WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_social.gd

const QuestDB := preload("res://scripts/quest_db.gd")
const LoreDB := preload("res://scripts/lore_db.gd")

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var stage := 0
var ticks := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.save_path = "user://screenshot_social_save.json"
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _next(to: int) -> void:
	stage = to
	ticks = 0


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() <= 320:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	image.save_png(shot_dir.path_join(name))
	print("SHOT " + name)


func _npc(id: String) -> Node:
	for zone_id in main.zones:
		for npc in main.zones[zone_id]["npcs"].npcs():
			if String(npc.npc_id) == id:
				return npc
	return null


func _stand_by(id: String) -> void:
	var npc := _npc(id)
	var map: Node2D = main.zones["town"]["map"]
	var cell: Vector2i = map.world_to_cell(npc.global_position)
	player.global_position = map.get_global_cell_center(cell + Vector2i(0, 1))
	player.facing = "north"


func _hold(item_id: String) -> void:
	var inv = player.inventory
	for i in inv.slots.size():
		if String(inv.get_slot(i).get("item_id", "")) == item_id:
			if i >= inv.HOTBAR_SIZE:
				inv.move_slot(i, inv.HOTBAR_SIZE - 1)
				i = inv.HOTBAR_SIZE - 1
			inv.select_hotbar(i)
			return


func _press(ui: Node, action: String, pressed := true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	ui._unhandled_input(event)


func _physics_process(_delta: float) -> bool:
	ticks += 1
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			day_manager.time_paused = true
			day_manager.minutes_into_day = 11 * 60.0
			main._bind_zone("town", Vector2i(17, 5))
			player.facing = "north"
			player.set_credits(420)
			player.inventory.add_item("wood", 18)
			player.inventory.add_item("stone", 40)
			main.quests.contribute("clinic", player, day_manager.day)
			# A deliverable request on the board.
			for t in QuestDB.templates():
				if String(t["kind"]) == "deliver" and String(t["npc"]) == "marta":
					var item: String = QuestDB.pool_items(String(t.get("pool", "crop")), day_manager.season())[0] \
						if t.has("pool") else String(t["items"][0])
					main.quests.posted = {"template": String(t["id"]), "npc": "marta", "kind": "deliver",
						"item": item, "count": 5, "posted_day": day_manager.day, "reward": QuestDB.delivery_reward(item, 5)}
					break
			main.notice_ui.open()
			_next(1)
		1:
			if ticks == 14:
				_shot("shot_notice_request_4x.png")
				_press(main.notice_ui, "move_down")
				_press(main.notice_ui, "move_down")
			if ticks == 22:
				_shot("shot_notice_works_4x.png")
				_press(main.notice_ui, "move_up")
				_press(main.notice_ui, "move_up")
				_press(main.notice_ui, "use_tool", false)
				_press(main.notice_ui, "use_tool")  # accept
				main.notice_ui.close()
				# Meet Doc, then come back tomorrow with a gift.
				main.get_node("DialogueUI").open_dialogue(_npc("doc_ama"))
				main.get_node("DialogueUI").close()
				day_manager.skip_to_next_morning()
				day_manager.minutes_into_day = 10 * 60.0
				_next(2)
		2:
			if ticks == 4:
				if main.confirm_ui.active:
					main.confirm_ui.choose(0)
				_stand_by("doc_ama")
				player.inventory.add_item("cleanleaf_kale", 3)
				_hold("cleanleaf_kale")
			if ticks == 8:
				var dlg: Node = main.get_node("DialogueUI")
				dlg.open_dialogue(_npc("doc_ama"))
				dlg._elapsed = 999.0
				dlg._refresh_body()
			if ticks == 14:
				_shot("shot_gift_offer_4x.png")
				var dlg: Node = main.get_node("DialogueUI")
				_press(dlg, "use_tool")
				dlg._elapsed = 999.0
				dlg._refresh_body()
			if ticks == 20:
				_shot("shot_gift_reply_4x.png")
				main.get_node("DialogueUI").close()
				# Some history for the journal and the people tab.
				for n in LoreDB.notes().slice(0, 3):
					main.expedition.notes_read.append(String(n["id"]))
				main.affinity.adjust_points("marta", 900)
				main.affinity.adjust_points("scout_kael", 400)
				main.affinity.adjust_points("wren", 1300)
				main.affinity.give_gift("marta", "bottle_caps", day_manager.day, false)
				var menu: Node = main.get_node("MenuScreen")
				menu.open_menu()
				menu.tab_index = menu.TAB_JOURNAL
				menu._refresh()
			if ticks == 26:
				_shot("shot_journal_4x.png")
				var menu: Node = main.get_node("MenuScreen")
				menu.journal_page = menu.JOURNAL_NOTES
				menu._refresh()
			if ticks == 29:
				_shot("shot_journal_note_4x.png")
				var menu: Node = main.get_node("MenuScreen")
				menu.journal_page = menu.JOURNAL_TODAY
				menu.tab_index = menu.TAB_PEOPLE
				menu._people_index = 0
				menu._refresh()
			if ticks == 32:
				_shot("shot_people_4x.png")
				main.get_node("MenuScreen").close()
				# Finish every project and look at the town and the greenhouse.
				for id in QuestDB.project_ids():
					main.quests.finished[id] = day_manager.day
				main.town_works.apply()
				main._bind_zone("town", Vector2i(6, 6))
				day_manager.minutes_into_day = 19.5 * 60.0
				day_manager.time_changed.emit(day_manager.day, day_manager.minutes_into_day)
				_next(3)
		3:
			if ticks == 10:
				_shot("shot_town_works_dusk_4x.png")
				day_manager.minutes_into_day = 12 * 60.0
				day_manager.time_changed.emit(day_manager.day, day_manager.minutes_into_day)
				player.global_position = main.zones["town"]["map"].get_global_cell_center(Vector2i(8, 11))
			if ticks == 20:
				_shot("shot_town_clinic_4x.png")
				var gh: Node = main.town_works.greenhouse
				main._bind_zone("farm", gh.top_left + Vector2i(3, 7))
				var farm: Node = main.zones["farm"]["farm"]
				var i := 0
				for cell in gh.interior_cells(gh.top_left):
					farm.till(cell)
					farm.plant(cell, ["frostroot", "glow_melon", "rain_radish", "ember_pumpkin"][i % 4])
					i += 1
			if ticks == 30:
				_shot("shot_greenhouse_4x.png")
				game_state.delete_save()
				quit(0)
				return true
	return false
