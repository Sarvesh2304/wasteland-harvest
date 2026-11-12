extends Node
## Festivals, live (Milestone D 2026-11-11, docs/LIVING_SETTLEMENT.md §4). One instance under
## Main. On a festival day the town square is dressed (bunting, lanterns, a food table and the
## striped booth), everyone gathers there from 9 AM, and the booth runs the day's activity:
## a seed hunt, a goat race, the harvest show or the winter gift circle. The rules are
## scripts/festival_db.gd's; this node owns what's been done each year and the town dressing.

signal changed

const FestivalDB := preload("res://scripts/festival_db.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const Calendar := preload("res://scripts/calendar.gd")

const BOOTH_ID := "festival_booth"
const BOOTH_CELL := Vector2i(18, 5)
const BOOTH_SIZE := Vector2i(2, 1)
const TABLE_ID := "festival_table"
const TABLE_CELL := Vector2i(14, 5)
const TABLE_SIZE := Vector2i(2, 1)
const DRESS_TAG := "festival"
const GATHER_FROM_MINUTES := 9 * 60.0
## Evening: the party breaks up and everyone goes back to their usual day (the dressing stays up
## till morning, lanterns lit).
const GATHER_UNTIL_MINUTES := 18 * 60.0
const PACKET_KIND := "forage_seed_packet"
## Where each of the townsfolk stands in the square (a festival's own "spots" override these).
const SPOTS := {
	"mayor_harlan": Vector2i(16, 5), "marta": Vector2i(20, 7), "scout_kael": Vector2i(21, 5),
	"rancher_silas": Vector2i(17, 6), "brask": Vector2i(13, 5), "wren": Vector2i(19, 8),
	"doc_ama": Vector2i(15, 7),
}
## Temporary dressing (props.gd add_temp entries; never solid).
const DRESSING := [
	{"kind": "bunting", "art": "props/bunting", "cell": Vector2i(13, 3), "size": Vector2i(5, 0)},
	{"kind": "bunting", "art": "props/bunting", "cell": Vector2i(17, 3), "size": Vector2i(5, 0)},
	{"kind": "festival_lantern", "art": "props/festival_lantern", "cell": Vector2i(12, 6), "size": Vector2i(1, 1),
		"frames": 2, "night_frame": 1, "light": ["#ffb86b", 0.8, 0.8, 22]},
	{"kind": "festival_lantern", "art": "props/festival_lantern", "cell": Vector2i(22, 6), "size": Vector2i(1, 1),
		"frames": 2, "night_frame": 1, "light": ["#ffb86b", 0.8, 0.8, 22]},
	{"kind": "festival_lantern", "art": "props/festival_lantern", "cell": Vector2i(15, 9), "size": Vector2i(1, 1),
		"frames": 2, "night_frame": 1, "light": ["#ffb86b", 0.8, 0.8, 22]},
	{"kind": "festival_lantern", "art": "props/festival_lantern", "cell": Vector2i(20, 9), "size": Vector2i(1, 1),
		"frames": 2, "night_frame": 1, "light": ["#ffb86b", 0.8, 0.8, 22]},
]
const GOAT_TINTS: Array[String] = ["#e8e2d2", "#b98a5a", "#8f8f9c", "#d6c27a"]

var main: Node = null
## "id:year" -> what happened (the hunt's count, the show's place, true...).
var done: Dictionary = {}
## "id:year" -> races run that day.
var races: Dictionary = {}
## The winter gift circle: {"year", "friend", "giver", "given", "opened"}.
var circle: Dictionary = {}
var base_seed := 0
## How long a goat race takes to watch (the smoke test shortens it).
var race_seconds := 5.0

var _dressed := ""
var _gathered := false
var _released := false
var _stand_in: Node = null
var _hunt: Dictionary = {}
var _race_node: Node2D = null


func setup(main_node: Node) -> void:
	main = main_node
	main.player.works_used.connect(func(id: String) -> void:
		if id == BOOTH_ID:
			open_booth())
	main.affinity.gift_given.connect(_on_gift_given)


func today() -> Dictionary:
	return FestivalDB.on_day(DayManager.day)


func next_festival(day: int) -> Dictionary:
	return FestivalDB.next_festival(day)


## Dialogue flags: festival_<id> on the day, festival_tomorrow the day before.
func flags(day: int) -> Dictionary:
	var out := {}
	var f := FestivalDB.on_day(day)
	if not f.is_empty():
		out["festival_" + String(f["id"])] = true
	if not FestivalDB.on_day(day + 1).is_empty():
		out["festival_tomorrow"] = true
	return out


## The morning: yesterday's festival comes down, today's goes up, and tomorrow's is announced.
func on_day_started(day: int, announce: bool = true) -> void:
	_undress()
	var f := FestivalDB.on_day(day)
	if not f.is_empty():
		_dress(f)
		if announce:
			Events.message.emit("%s today! Everyone's in the square from nine." % String(f.get("name", "A festival")))
	elif announce:
		var tomorrow := FestivalDB.on_day(day + 1)
		if not tomorrow.is_empty():
			Events.message.emit(String(tomorrow.get("announce", "%s is tomorrow." % String(tomorrow.get("name", "")))))
	_maybe_draw_circle(day, announce)
	changed.emit()


func _process(_delta: float) -> void:
	if _dressed != "" and not _gathered and DayManager.minutes_into_day >= GATHER_FROM_MINUTES \
			and DayManager.minutes_into_day < GATHER_UNTIL_MINUTES:
		_gather(FestivalDB.festival(_dressed))
	elif _gathered and not _released and DayManager.minutes_into_day >= GATHER_UNTIL_MINUTES:
		_release()
	if not _hunt.is_empty() and not main.modal_gate.is_any_open():
		var remaining: int = main.zones["town"]["objects"].count_kinds([PACKET_KIND])
		if remaining == 0 or DayManager.minutes_into_day >= float(_hunt["end"]) \
				or DayManager.day != int(_hunt["day"]):
			_end_hunt()


## -- Dressing the square --

func _dress(f: Dictionary) -> void:
	_dressed = String(f["id"])
	_gathered = false
	_released = false
	var town: Node = main.zones["town"]["structures"]
	town.add_works_building(BOOTH_ID, "festival_booth", BOOTH_CELL, BOOTH_SIZE)
	town.add_works_building(TABLE_ID, "festival_table", TABLE_CELL, TABLE_SIZE)
	var props: Node = main.zones["town"]["map"].get_node("Props")
	for entry in DRESSING:
		props.add_temp(DRESS_TAG, entry)


func _gather(f: Dictionary) -> void:
	_gathered = true
	var spots: Dictionary = f.get("spots", {})
	var town_npcs: Node = main.zones["town"]["npcs"]
	for id in SPOTS:
		var cell: Vector2i = SPOTS[id]
		if spots.has(id):
			cell = Vector2i(int(spots[id][0]), int(spots[id][1]))
		var npc: Node = town_npcs.npc_by_id(String(id))
		if npc == null and String(id) == "rancher_silas":
			# Silas lives on the ranch: he's away from it today, and a stand-in walks the square.
			main.zones["ranch"]["npcs"].set_away("rancher_silas", true)
			_stand_in = town_npcs.spawn_settler("rancher_silas", cell, 1)
			npc = _stand_in
		if npc != null:
			npc.gather_cell = cell
	main._refresh_npc_markers()


func _undress() -> void:
	if not _hunt.is_empty():
		_end_hunt(false)
	if _dressed == "":
		return
	_dressed = ""
	var town: Node = main.zones["town"]["structures"]
	town.remove_works_building(BOOTH_ID, BOOTH_CELL, BOOTH_SIZE)
	town.remove_works_building(TABLE_ID, TABLE_CELL, TABLE_SIZE)
	main.zones["town"]["map"].get_node("Props").clear_temp(DRESS_TAG)
	_release()
	_gathered = false
	_clear_packets()


## Everyone back to their own day; Silas goes home to the ranch.
func _release() -> void:
	_released = true
	var town_npcs: Node = main.zones["town"]["npcs"]
	for npc in town_npcs.npcs():
		npc.gather_cell = npc.NO_GATHER
	if _stand_in != null and is_instance_valid(_stand_in):
		town_npcs.despawn_npc(_stand_in)
	_stand_in = null
	main.zones["ranch"]["npcs"].set_away("rancher_silas", false)


func is_dressed() -> bool:
	return _dressed != ""


## -- The booth --

func open_booth() -> void:
	var f := today()
	if f.is_empty():
		return
	match String(f.get("activity", "")):
		"seed_hunt":
			_booth_seed_hunt(f)
		"goat_race":
			_booth_goat_race(f)
		"harvest_show":
			_booth_harvest_show(f)
		"gift_circle":
			_booth_gift_circle(f)


func _key(f: Dictionary) -> String:
	return FestivalDB.key(String(f["id"]), DayManager.day)


func _title(f: Dictionary) -> String:
	return String(f.get("booth_title", f.get("name", "Festival")))


func _rng(salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = DialogueDB.daily_seed("festival", DayManager.day, "%d|%s" % [base_seed, salt])
	return rng


func _pay(credits: int, items: Dictionary = {}) -> void:
	if credits > 0:
		main.player.add_credits(credits)
	if not items.is_empty():
		main.player.add_items(items)


## -- Seed hunt (Planting Day) --

func _booth_seed_hunt(f: Dictionary) -> void:
	var key := _key(f)
	if done.has(key):
		main.confirm_ui.show_text(_title(f), "The hunt's over for this year. You found %d of %d." % [
			int(done[key]), FestivalDB.HUNT_PACKETS])
		return
	if not _hunt.is_empty():
		var found: int = int(_hunt["total"]) - int(main.zones["town"]["objects"].count_kinds([PACKET_KIND]))
		main.confirm_ui.show_text(_title(f), "You've found %d so far. They're all over town. Keep looking!" % found)
		return
	main.confirm_ui.ask(_title(f), String(f.get("booth_text", "Twelve seed packets are hidden around town. Find as many as you can in two hours.")),
		["Start the hunt", "Not yet"], func(choice: int) -> void:
			if choice == 0:
				_start_hunt(f))


func _start_hunt(f: Dictionary) -> void:
	var objects: Node = main.zones["town"]["objects"]
	var map: Node2D = main.zones["town"]["map"]
	var size: Vector2i = map.layout.size()
	var rng := _rng("hunt")
	var placed := 0
	var guard := 0
	while placed < FestivalDB.HUNT_PACKETS and guard < 2000:
		guard += 1
		var cell := Vector2i(rng.randi_range(1, size.x - 2), rng.randi_range(1, size.y - 2))
		if map.is_blocked_at(cell) or objects.has_object(cell) or main.zones["town"]["npcs"].npc_at(cell) != null:
			continue
		if objects.add_generated(PACKET_KIND, cell):
			placed += 1
	_hunt = {"id": String(f["id"]), "day": DayManager.day, "total": placed,
		"end": minf(DayManager.minutes_into_day + FestivalDB.HUNT_MINUTES, 23.0 * 60.0 + 59.0)}
	Audio.play_sfx("day_start", -6.0)
	Events.message.emit(String(f.get("start", "Go! %d packets, two hours." % placed)))


func _end_hunt(show: bool = true) -> void:
	var f := FestivalDB.festival(String(_hunt.get("id", "")))
	var total := int(_hunt.get("total", 0))
	var hunt_day := int(_hunt.get("day", DayManager.day))
	_hunt = {}
	var found: int = total - int(main.zones["town"]["objects"].count_kinds([PACKET_KIND]))
	_clear_packets()
	done[FestivalDB.key(String(f.get("id", "planting_day")), hunt_day)] = found
	var result := FestivalDB.hunt_result(found)
	_pay(int(result["credits"]), result["items"])
	changed.emit()
	if not show:
		return
	var text := String((f.get("results", {}) as Dictionary).get(String(result["tier"]), "You found {count}."))
	text = DialogueDB.fill(text, {"count": found})
	Audio.play_stinger("stinger_victory", -6.0)
	main.confirm_ui.show_text(_title(f), "%s\n\nYou found %d of %d. Wren found %d. Prize: %d Cr%s." % [text, found,
		total, FestivalDB.HUNT_WREN_FOUND, int(result["credits"]),
		" and 3 Glow Melon Seeds" if not (result["items"] as Dictionary).is_empty() else ""])


func _clear_packets() -> void:
	var objects: Node = main.zones["town"]["objects"]
	var all: Dictionary = objects.all_objects()
	for anchor in all.keys():
		if String(all[anchor]["kind"]) == PACKET_KIND:
			objects.remove(anchor)


## -- Goat race (Scorch Fair) --

func goats(f: Dictionary) -> Array:
	var list: Array = f.get("goats", [])
	if list.size() == 4:
		return list
	return [{"name": "Dorothy", "odds": 2}, {"name": "Biscuit", "odds": 3}, {"name": "Rivet", "odds": 4},
		{"name": "Old Tin", "odds": 6}]


func _booth_goat_race(f: Dictionary) -> void:
	var key := _key(f)
	var run := int(races.get(key, 0))
	if run >= FestivalDB.RACES_PER_DAY:
		main.confirm_ui.show_text(_title(f), "That's the goats done for the day. Silas is walking them home.")
		return
	if int(main.player.credits) < FestivalDB.RACE_STAKE:
		main.confirm_ui.show_text(_title(f), "A bet is %d Cr, and you haven't got it. You can still cheer." % FestivalDB.RACE_STAKE)
		return
	var field := goats(f)
	var choices: Array = []
	for goat in field:
		choices.append("%s (pays %d to 1)" % [String(goat["name"]), int(goat["odds"])])
	choices.append("Just watching")
	main.confirm_ui.ask(_title(f), "%s\n\nRace %d of %d. A bet is %d Cr." % [String(f.get("booth_text",
		"Four goats, one square. Pick your runner.")), run + 1, FestivalDB.RACES_PER_DAY, FestivalDB.RACE_STAKE],
		choices, func(choice: int) -> void:
			if choice < field.size():
				_run_race(f, choice))


func _run_race(f: Dictionary, pick: int) -> void:
	var key := _key(f)
	var run := int(races.get(key, 0))
	races[key] = run + 1
	var field := goats(f)
	var rng := _rng("race%d" % run)
	var winner := FestivalDB.race_winner(field, rng)
	main.player.set_credits(int(main.player.credits) - FestivalDB.RACE_STAKE)
	main.player.watching = true
	_play_race(field, winner, rng, func() -> void:
		main.player.watching = false
		var won := winner == pick
		var payout := FestivalDB.race_payout(int(field[pick]["odds"]))
		if won:
			main.player.add_credits(payout)
			Audio.play_stinger("stinger_victory", -6.0)
		var text := String(f.get("win" if won else "lose", "{winner} wins!"))
		text = DialogueDB.fill(text, {"goat": String(field[pick]["name"]), "winner": String(field[winner]["name"])})
		main.confirm_ui.show_text(_title(f), "%s\n\n%s" % [text, "You win %d Cr." % payout if won
			else "%s came home first. Your %d Cr is gone." % [String(field[winner]["name"]), FestivalDB.RACE_STAKE]])
		changed.emit())


## Four goats cross the square, east to west; the winner gets there first. Dorothy (the first
## goat) sometimes stops to bite a rival on the way.
func _play_race(field: Array, winner: int, rng: RandomNumberGenerator, on_done: Callable) -> void:
	var map: Node2D = main.zones["town"]["map"]
	_race_node = Node2D.new()
	_race_node.z_index = 6
	map.add_child(_race_node)
	var path := "res://art/fx/race_goat.png"
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var start_x := 21.5 * 16.0
	var end_x := 13.2 * 16.0
	var longest := 0.0
	for i in field.size():
		var goat := Sprite2D.new()
		if texture != null:
			goat.texture = texture
			goat.hframes = 4
		goat.modulate = Color(GOAT_TINTS[i % GOAT_TINTS.size()])
		goat.position = Vector2(start_x, 7.4 * 16.0 + float(i) * 6.0)
		_race_node.add_child(goat)
		var seconds := race_seconds * (0.72 if i == winner else rng.randf_range(0.8, 1.0))
		longest = maxf(longest, seconds)
		var run := create_tween()
		if i == 0 and i != winner and rng.randf() < 0.6:
			# Dorothy stops to bite somebody.
			run.tween_property(goat, "position:x", lerpf(start_x, end_x, 0.45), seconds * 0.35)
			run.tween_interval(seconds * 0.25)
			run.tween_property(goat, "position:x", end_x, seconds * 0.4)
		else:
			run.tween_property(goat, "position:x", end_x, seconds).set_trans(Tween.TRANS_SINE)
		if texture != null:
			var legs := create_tween().set_loops()
			legs.tween_property(goat, "frame", 3, 0.3).from(0)
			legs.bind_node(goat)
	Audio.play_sfx("day_start", -8.0)
	var finish := create_tween()
	finish.tween_interval(longest + 0.4)
	finish.tween_callback(func() -> void:
		if _race_node != null and is_instance_valid(_race_node):
			_race_node.queue_free()
		_race_node = null
		on_done.call())


## -- Harvest show (Harvest Day) --

func _booth_harvest_show(f: Dictionary) -> void:
	var key := _key(f)
	if done.has(key):
		main.confirm_ui.show_text(_title(f), "The ribbons are pinned. You took %s place this year." % _ordinal(int(done[key])))
		return
	var have := {}
	for slot in main.player.inventory.slots:
		var item_id := String((slot as Dictionary).get("item_id", ""))
		if item_id != "":
			have[item_id] = int(have.get(item_id, 0)) + int((slot as Dictionary).get("count", 0))
	var entry := FestivalDB.show_entry(have)
	if (entry["items"] as Array).is_empty():
		main.confirm_ui.show_text(_title(f), "%s\n\nYou've nothing to put on the table. Bring things you grew, foraged, cooked or made." % String(f.get("booth_text", "")))
		return
	var names: Array[String] = []
	for item_id in entry["items"]:
		names.append(ItemDB.display_name(String(item_id)))
	main.confirm_ui.ask(_title(f), "%s\n\nYour table: %s. (You keep them.)" % [String(f.get("booth_text",
		"Your best five go on the table.")), ", ".join(names)], ["Enter the show", "Not yet"],
		func(choice: int) -> void:
			if choice == 0:
				_judge_show(f, entry))


func _judge_show(f: Dictionary, entry: Dictionary) -> void:
	var year := Calendar.year(DayManager.day)
	var score := int(entry["score"])
	var place := FestivalDB.show_place(score, year)
	done[_key(f)] = place
	var prize := int(FestivalDB.SHOW_PRIZES.get(place, 0))
	_pay(prize)
	if place == 1:
		for id in SPOTS:
			main.affinity.adjust_points(String(id), FestivalDB.SHOW_WIN_FRIENDSHIP)
		if ItemDB.has_item("festival_ribbon"):
			_pay(0, {"festival_ribbon": 1})
		Audio.play_stinger("stinger_victory", -4.0)
	var board: Array[String] = ["You %d" % score]
	for rival in FestivalDB.rival_scores(year):
		board.append("%s %d" % [DialogueDB.display_name(String(rival[0])), int(rival[1])])
	var text := DialogueDB.fill(String((f.get("results", {}) as Dictionary).get(str(place), "")), {"score": score})
	main.confirm_ui.show_text(_title(f), "%s\n\n%s place: %d Cr.\n%s." % [text, _ordinal(place).capitalize(), prize,
		", ".join(board)])
	changed.emit()


static func _ordinal(place: int) -> String:
	return ["first", "second", "third", "fourth"][clampi(place, 1, 4) - 1]


## -- Gift circle (Winter Gathering) --

## Draws this year's names a week before the gathering (or late, if the game was loaded past it).
func _maybe_draw_circle(day: int, announce: bool) -> void:
	var f := _circle_festival()
	if f.is_empty() or Calendar.season(day) != String(f["season"]):
		return
	var dom := Calendar.day_of_season(day)
	if dom < FestivalDB.CIRCLE_DRAW_DAY or dom > int(f["day"]):
		return
	var year := Calendar.year(day)
	if int(circle.get("year", -1)) == year:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = DialogueDB.daily_seed("circle", year, str(base_seed))
	circle = FestivalDB.circle_draw(SPOTS.keys(), rng)
	circle["year"] = year
	circle["given"] = false
	circle["opened"] = false
	if announce:
		Events.message.emit(DialogueDB.fill(String(f.get("draw", "You drew {npc}'s name for the Winter Gathering.")),
			{"npc": DialogueDB.display_name(String(circle["friend"]))}))


func _circle_festival() -> Dictionary:
	for f in FestivalDB.festivals():
		if String(f.get("activity", "")) == "gift_circle":
			return f
	return {}


## Whether a gift to `npc_id` today is the player's gift-circle gift (it counts five times).
func is_circle_gift(npc_id: String) -> bool:
	var f := today()
	return not f.is_empty() and String(f.get("activity", "")) == "gift_circle" \
		and String(circle.get("friend", "")) == npc_id and not bool(circle.get("given", false)) \
		and int(circle.get("year", -1)) == Calendar.year(DayManager.day)


func _on_gift_given(npc_id: String, _item_id: String, _reaction: String, _points: int) -> void:
	if is_circle_gift(npc_id):
		circle["given"] = true
		Events.message.emit("%s opens your Winter Gathering gift." % DialogueDB.display_name(npc_id))
		changed.emit()


func _booth_gift_circle(f: Dictionary) -> void:
	_maybe_draw_circle(DayManager.day, false)
	var friend := DialogueDB.display_name(String(circle.get("friend", "")))
	var reminder := "You drew %s's name: %s." % [friend, "your gift is given" if bool(circle.get("given", false))
		else "hand them a gift today and it counts five times"]
	if bool(circle.get("opened", false)):
		main.confirm_ui.show_text(_title(f), "You've opened yours. %s" % reminder)
		return
	main.confirm_ui.ask(_title(f), "%s\n\n%s" % [String(f.get("booth_text", "There's a parcel here with your name on it.")),
		reminder], ["Open your gift", "Later"], func(choice: int) -> void:
			if choice == 0:
				_open_circle_gift(f))


func _open_circle_gift(f: Dictionary) -> void:
	var giver := String(circle.get("giver", ""))
	var item := String((f.get("gifts", {}) as Dictionary).get(giver, "cooked_meal"))
	if not ItemDB.has_item(item):
		item = "cooked_meal"
	circle["opened"] = true
	_pay(0, {item: 1})
	Audio.play_sfx("achievement", -4.0)
	main.confirm_ui.show_text(_title(f), DialogueDB.fill(String(f.get("open", "It's from {npc}: {item}.")),
		{"npc": DialogueDB.display_name(giver), "item": ItemDB.display_name(item)}))
	changed.emit()


## -- Save/load --

func save_state() -> Dictionary:
	return {"done": done, "races": races, "circle": circle, "seed": base_seed}


func load_state(data: Dictionary) -> void:
	base_seed = int(data.get("seed", 0))
	done = {}
	var raw_done = data.get("done", {})
	if raw_done is Dictionary:
		for key in raw_done:
			done[String(key)] = int(raw_done[key])
	races = {}
	var raw_races = data.get("races", {})
	if raw_races is Dictionary:
		for key in raw_races:
			races[String(key)] = int(raw_races[key])
	circle = {}
	var raw_circle = data.get("circle", {})
	if raw_circle is Dictionary and raw_circle.has("friend"):
		circle = {"year": int(raw_circle.get("year", -1)), "friend": String(raw_circle["friend"]),
			"giver": String(raw_circle.get("giver", "")), "given": bool(raw_circle.get("given", false)),
			"opened": bool(raw_circle.get("opened", false))}
