extends Node
## The main story, The Signal (Milestone D, docs/LIVING_SETTLEMENT.md §5). One instance under
## Main. Harlan's dead radio catches a broadcast: he needs three Radio Parts for an antenna, the
## broadcast names the Northgate seed vault under The Core, and the player opens it and chooses
## what the town does with the seed. The story is a thread, not an ending (GDD §10): the choice
## changes the world and the game goes on.
##
## Stages: "" (not started) -> static -> radio_parts -> broadcast -> find_vault -> decision ->
## done_home | done_shared. The text is data/story.json and Harlan's story_* dialogue nodes.

signal changed

const PATH := "res://data/story.json"
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const CropDB := preload("res://scripts/crop_db.gd")
const Calendar := preload("res://scripts/calendar.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")

const HARLAN := "mayor_harlan"
const STAGES: Array[String] = ["static", "radio_parts", "broadcast", "find_vault", "decision",
	"done_home", "done_shared"]
const START_DAY := 8
const PARTS_NEEDED := 3
const PART_ITEM := "radio_part"
const KEYCARD := "keycard"
const SEEDS_ITEM := "vault_seeds"
const VAULT_KIND := "vault_door"
const VAULT_DEPTH := 4
## The door's status lamp once it opens (tools/art/palette.py VAULT_LAMP_GREEN).
const VAULT_OPEN_LAMP := "#3fe0a8"
const CODE_NOTE := "seed_vault"
const CODE_LINE := "wren_vault_code"
const ANTENNA_ART := "mayor_house_antenna"
## done_home: the good stock yields more (a chance of one more per harvest), and Harlan's share.
const HOME_EXTRA_CHANCE := 0.25
const HOME_SHARE_KINDS := 2
const HOME_SHARE_EACH := 3
## done_shared: Tully comes four days a week with more on the stall; Marta wants more things.
const SHARED_WEEKDAYS: Array[String] = ["Mon", "Fri"]
const SHARED_EXTRA_OFFERS := 2
const SHARED_DEMAND_COUNT := 5

var main: Node = null
var stage := ""
var parts_given := 0
## The antenna goes up the night Harlan gets the last part.
var antenna_pending := false
## The morning notice the next day brings (a stage id), or "".
var notice_pending := ""
## The stages already passed, in order (the journal's "Before").
var history: Array[String] = []

var _data: Dictionary = {}
var _vault_anchor := Vector2i(-1, -1)


func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_data = parsed if parsed is Dictionary else {}


func setup(main_node: Node) -> void:
	main = main_node
	main.expedition.level_entered.connect(_on_level_entered)
	main.ruins["objects"].door_used.connect(_on_door_used)
	Events.item_gained.connect(func(item_id: String, _count: int) -> void:
		if item_id == PART_ITEM or item_id == SEEDS_ITEM:
			main._refresh_npc_markers())


func stage_data(id: String) -> Dictionary:
	return (_data.get("stages", {}) as Dictionary).get(id, {})


func at_least(id: String) -> bool:
	if stage == "":
		return false
	if stage == "done_home" or stage == "done_shared":
		return true if id != "done_home" and id != "done_shared" else stage == id
	return STAGES.find(stage) >= STAGES.find(id)


func _set_stage(id: String) -> void:
	if stage != "":
		history.append(stage)
	stage = id
	main._refresh_npc_markers()
	changed.emit()


## -- Dialogue --

## Flags for daily lines (§6).
func flags() -> Dictionary:
	var out := {}
	if at_least("static"):
		out["story_signal"] = true
	if at_least("find_vault"):
		out["story_broadcast"] = true
	if at_least("decision"):
		out["story_vault_open"] = true
	if stage == "done_home":
		out["story_home"] = true
	elif stage == "done_shared":
		out["story_shared"] = true
	return out


## Whether Harlan has something to say about the story (his "!").
func wants_talk(npc_id: String) -> bool:
	if npc_id != HARLAN:
		return false
	match stage:
		"static":
			return true
		"radio_parts":
			return not antenna_pending and _held(PART_ITEM) > 0
		"decision":
			return _held(SEEDS_ITEM) > 0
	return false


## What a conversation with `npc_id` opens with: "" (an ordinary chat), one of Harlan's story
## node ids, or {"text": ...} (a one-off line). Pure: story_opened (on_opened) does the work.
func conversation_for(npc_id: String) -> Variant:
	if npc_id != HARLAN:
		return ""
	match stage:
		"static":
			return "story_static"
		"radio_parts":
			if antenna_pending:
				return ""
			var held := _held(PART_ITEM)
			if held <= 0:
				return ""
			if parts_given + held >= PARTS_NEEDED:
				return "story_parts"
			return {"text": String(stage_data("radio_parts").get("have_some",
				"Every part helps. Three in all, farmer."))}
		"decision":
			if _held(SEEDS_ITEM) > 0:
				return "story_decision"
	return ""


func on_opened(npc_id: String, what: Variant) -> void:
	if npc_id != HARLAN:
		return
	if what is Dictionary:
		# Fewer than three: he keeps what you brought.
		var held := _held(PART_ITEM)
		main.player.inventory.remove_item(PART_ITEM, held)
		parts_given += held
		Events.message.emit("Harlan has %d of %d Radio Parts." % [parts_given, PARTS_NEEDED])
		main._refresh_npc_markers()
		changed.emit()
		return
	match String(what):
		"story_static":
			_set_stage("radio_parts")
		"story_parts":
			var take := mini(_held(PART_ITEM), PARTS_NEEDED - parts_given)
			main.player.inventory.remove_item(PART_ITEM, take)
			parts_given = PARTS_NEEDED
			antenna_pending = true
			main._refresh_npc_markers()
			changed.emit()


## Harlan's two choices (dialogue_ui's STORY_HOME / STORY_SHARED sentinels).
func on_choice(npc: Node, choice: String) -> void:
	if stage != "decision":
		return
	main.player.inventory.remove_item(SEEDS_ITEM, _held(SEEDS_ITEM))
	_set_stage("done_home" if choice == "home" else "done_shared")
	notice_pending = stage
	apply_effects()
	Audio.play_stinger("stinger_victory", -4.0)
	if npc != null and is_instance_valid(npc):
		main.get_node("DialogueUI").open_dialogue_at(npc, "story_%s_end" % ("home" if choice == "home" else "shared"))


## -- The morning --

## Returns the morning's story notices: [[title, text], ...].
func on_day_started(day: int) -> Array:
	var out: Array = []
	if stage == "" and day >= START_DAY and int(main.expedition.runs) >= 1:
		_set_stage("static")
		out.append(_notice("static"))
	elif stage == "radio_parts" and antenna_pending:
		antenna_pending = false
		_set_stage("broadcast")
		apply_effects()
		out.append(_notice("broadcast"))
		# Reading the morning notice is the stage: the hunt for the vault starts now.
		_set_stage("find_vault")
	if notice_pending != "":
		out.append(_notice(notice_pending))
		notice_pending = ""
	if stage == "done_home" and Calendar.weekday(day) == "Mon":
		_send_share(day)
	return out


func _notice(id: String) -> Array:
	var data := stage_data(id)
	return [String(data.get("title", "The Signal")), String(data.get("notice", ""))]


## done_home: every Monday Harlan sends a share of the town harvest (the season's crops).
func _send_share(day: int) -> void:
	var crops := CropDB.crops_for_season(Calendar.season(day))
	if crops.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = DialogueDB.daily_seed("story_share", day, "")
	var share := {}
	for i in mini(HOME_SHARE_KINDS, crops.size()):
		var crop := CropDB.get_crop(crops[rng.randi_range(0, crops.size() - 1)])
		var item := String(crop.get("yield_item", ""))
		if ItemDB.has_item(item):
			share[item] = int(share.get(item, 0)) + HOME_SHARE_EACH
	if share.is_empty():
		return
	main.player.add_items(share)
	var names: Array[String] = []
	for item in share:
		names.append("%d %s" % [int(share[item]), ItemDB.display_name(String(item))])
	Events.message.emit("Harlan's share of the town harvest: %s." % ", ".join(names))


## What the story has changed in the world, re-applied after a load: the antenna on Harlan's
## house, and the decision's lasting effects.
func apply_effects() -> void:
	if at_least("broadcast"):
		main.zones["town"]["structures"].set_layout_art("mayor_house", ANTENNA_ART)
	var extra := HOME_EXTRA_CHANCE if stage == "done_home" else 0.0
	for zone_id in main.zones:
		var farm: Node = main.zones[zone_id].get("farm")
		if farm != null and "vault_extra_chance" in farm:
			farm.vault_extra_chance = extra
	if stage == "done_shared":
		main.caravan.extra_weekdays = SHARED_WEEKDAYS.duplicate()
		main.caravan.extra_offers = SHARED_EXTRA_OFFERS
		main.market.demand_count = SHARED_DEMAND_COUNT


## -- The ruins: Radio Parts and the vault --

func _on_level_entered(depth: int, _level_name: String) -> void:
	_vault_anchor = Vector2i(-1, -1)
	if stage == "radio_parts" and not antenna_pending and parts_given + _held(PART_ITEM) < PARTS_NEEDED:
		var cell := _free_cell(Vector2i(1, 1), "part%d" % depth)
		if cell.x >= 0:
			main.ruins["objects"].spawn_pickup(PART_ITEM, 1, main.ruins["map"].get_global_cell_center(cell))
	elif stage == "find_vault" and depth >= VAULT_DEPTH:
		var anchor := _free_cell(Vector2i(2, 3), "vault")
		if anchor.x >= 0 and main.ruins["objects"].add_generated(VAULT_KIND, anchor):
			_vault_anchor = anchor
			Events.message.emit("Somewhere down here, a little red light is blinking.")


## A free floor spot for a `size` footprint (plus a row in front of it), away from the truck.
func _free_cell(size: Vector2i, salt: String) -> Vector2i:
	var map: Node2D = main.ruins["map"]
	var objects: Node = main.ruins["objects"]
	var lvl: Dictionary = main.expedition.level
	var bounds: Vector2i = lvl.get("size", Vector2i(36, 20))
	var truck: Vector2i = lvl.get("truck", Vector2i(1, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = DialogueDB.daily_seed("story_" + salt, DayManager.day, str(main.expedition.runs))
	for attempt in 400:
		var c := Vector2i(rng.randi_range(2, bounds.x - size.x - 2), rng.randi_range(2, bounds.y - size.y - 2))
		if c.distance_to(truck) < 8.0:
			continue
		var ok := true
		for dx in size.x:
			for dy in size.y:
				var cell := c + Vector2i(dx, dy)
				if map.is_blocked_at(cell) or objects.has_object(cell):
					ok = false
		if ok and (size == Vector2i.ONE or objects.can_place(VAULT_KIND, c)):
			return c
	return Vector2i(-1, -1)


func code_known() -> bool:
	var read: Array = main.expedition.notes_read
	return read.has(CODE_NOTE) or main.affinity.has_seen_line(CODE_LINE)


func _on_door_used(anchor: Vector2i, kind: String) -> void:
	if kind != VAULT_KIND:
		return
	var data := stage_data("find_vault")
	var title := String(stage_data("find_vault").get("title", "The Vault"))
	if stage != "find_vault":
		main.confirm_ui.show_text(title, "The hatch stands open on a cold, empty stair.")
		return
	if _held(KEYCARD) <= 0:
		main.confirm_ui.show_text(title, String(data.get("need_keycard", "It wants a Keycard.")))
		return
	if not code_known():
		main.confirm_ui.show_text(title, String(data.get("need_code", "It wants a four-digit code.")))
		return
	main.confirm_ui.ask(title, "The card slot blinks green. The keypad waits for four digits.",
		["Key in 4-1-7-7", "Not now"], func(choice: int) -> void:
			if choice == 0:
				_open_vault(anchor))


func _open_vault(anchor: Vector2i) -> void:
	main.ruins["objects"].set_frame(anchor, 1, VAULT_OPEN_LAMP)
	main.player.inventory.remove_item(KEYCARD, 1)
	main.player.add_items({SEEDS_ITEM: 1})
	_set_stage("decision")
	Audio.play_stinger("stinger_victory", -4.0)
	var pages: Array = stage_data("find_vault").get("opening", [])
	_show_pages(String(stage_data("find_vault").get("title", "The Vault")), pages, 0)


func _show_pages(title: String, pages: Array, index: int) -> void:
	if index >= pages.size():
		Events.message.emit("You have the vault seed. Take it to Harlan.")
		return
	main.confirm_ui.ask(title, String(pages[index]), ["Next" if index < pages.size() - 1 else "Close"],
		func(_choice: int) -> void: _show_pages(title, pages, index + 1))


func _held(item: String) -> int:
	return int(main.player.inventory.count_of(item))


## -- The journal --

## {"title", "journal", "past": [titles]} for the journal's Story page; {} before it starts.
func journal_entry() -> Dictionary:
	if stage == "":
		return {}
	var data := stage_data(stage)
	var text := String(data.get("journal", ""))
	if stage == "radio_parts":
		text += " (%d of %d)" % [mini(parts_given + _held(PART_ITEM), PARTS_NEEDED), PARTS_NEEDED] \
			if not antenna_pending else " The antenna goes up tonight."
	var past: Array[String] = []
	for id in history:
		var t := String(stage_data(id).get("title", ""))
		if t != "" and not past.has(t):
			past.append(t)
	return {"title": String(data.get("title", "")), "journal": text, "past": past}


## -- Save section "story" --

func save_state() -> Dictionary:
	return {"stage": stage, "parts": parts_given, "antenna_pending": antenna_pending,
		"notice_pending": notice_pending, "history": history.duplicate()}


func load_state(data: Dictionary) -> void:
	stage = String(data.get("stage", ""))
	if stage != "" and not STAGES.has(stage):
		stage = ""
	parts_given = int(data.get("parts", 0))
	antenna_pending = bool(data.get("antenna_pending", false))
	notice_pending = String(data.get("notice_pending", ""))
	history.clear()
	for id in data.get("history", []):
		history.append(String(id))
