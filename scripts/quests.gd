extends Node
## The notice board's live state (Milestone B 2026-10-08, docs/SOCIAL_AND_QUESTS.md §5-6): today's
## posted request, the one the player has accepted, and the Town Works projects' contributions.
## One instance lives under Main, settlement-wide. The rules are scripts/quest_db.gd's.
##
## The day: main.gd calls on_day_started() each morning. Projects funded yesterday are finished
## (main.gd changes the town and shows the notice), an accepted request past its due day lapses,
## and a fresh request is posted. Postings are seeded by (game seed, day), so a reload posts the
## same notice.
##
## Requests: accept() takes the posted one. A delivery is handed in by talking to the requester
## while carrying everything (dialogue_ui.gd's delivery_hook calls try_deliver()). A hunt finishes
## itself on the last kill (main.gd forwards the expedition's kills to on_enemy_killed()). Either
## pays the reward and +150 friendship with the requester.

signal changed
signal request_completed(req: Dictionary, reward: int, thanks: String)
signal request_expired(req: Dictionary)

const QuestDB := preload("res://scripts/quest_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")

var posted: Dictionary = {}
var active: Dictionary = {}
var requests_done := 0
## project id -> {item: count, "credits": n} contributed so far
var given: Dictionary = {}
## project id -> the day it was fully funded (it's built the next morning)
var funded: Dictionary = {}
## project id -> the day it was finished
var finished: Dictionary = {}
var base_seed := 0
## Assigned by main.gd (requests pay friendship).
var affinity: Node = null


## A new game: a seed for the board and today's first notice.
func new_game(seed_value: int, day: int, season: String) -> void:
	base_seed = seed_value
	posted = {}
	active = {}
	requests_done = 0
	given = {}
	funded = {}
	finished = {}
	_post(day, season, 0, 0)
	changed.emit()


## The morning: returns the ids of Town Works projects finished overnight.
func on_day_started(day: int, season: String, runs: int, depth: int = 99) -> Array[String]:
	var done: Array[String] = []
	for id in funded.keys():
		if int(funded[id]) < day and not finished.has(id):
			finished[id] = day
			done.append(String(id))
	for id in done:
		funded.erase(id)
	if not active.is_empty() and day > int(active.get("due_day", day)):
		var lapsed := active
		active = {}
		request_expired.emit(lapsed)
	if posted.is_empty() or int(posted.get("posted_day", 0)) < day:
		_post(day, season, runs, depth)
	changed.emit()
	return done


func _post(day: int, season: String, runs: int, depth: int = 99) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = DialogueDB.daily_seed("board", day, str(base_seed))
	posted = QuestDB.generate(day, season, runs, rng, String(active.get("npc", "")), depth)


## -- Requests --

func can_accept() -> bool:
	return not posted.is_empty() and active.is_empty()


func accept(day: int) -> bool:
	if not can_accept():
		return false
	active = posted.duplicate()
	active["accepted_day"] = day
	active["due_day"] = day + QuestDB.DUE_DAYS
	active["progress"] = 0
	posted = {}
	changed.emit()
	return true


func days_left(day: int) -> int:
	return int(active.get("due_day", day)) - day if not active.is_empty() else 0


## Whether `npc_id` is waiting on the player's accepted request.
func is_requester(npc_id: String) -> bool:
	return not active.is_empty() and String(active.get("npc", "")) == npc_id


## For a delivery: whether `inventory` holds everything the request asks for.
func can_deliver(npc_id: String, inventory) -> bool:
	return is_requester(npc_id) and String(active.get("kind", "")) == "deliver" \
		and int(inventory.count_of(String(active["item"]))) >= int(active["count"])


## Hands the request in if `npc_id` is the requester and the player carries it all: takes the
## items, pays, and returns {"text": the thanks line, "reward": n}; {} otherwise.
func try_deliver(npc_id: String, player) -> Dictionary:
	if player == null or not can_deliver(npc_id, player.inventory):
		return {}
	player.inventory.remove_item(String(active["item"]), int(active["count"]))
	return _complete(player)


## A kill on an expedition: counts toward an accepted hunt, which finishes on the last one.
func on_enemy_killed(enemy_type: String, player) -> void:
	if active.is_empty() or String(active.get("kind", "")) != "hunt":
		return
	var want := String(active.get("enemy", "any"))
	if want != "any" and want != enemy_type:
		return
	active["progress"] = int(active.get("progress", 0)) + 1
	if int(active["progress"]) >= int(active["count"]):
		_complete(player)
	else:
		changed.emit()


func _complete(player) -> Dictionary:
	var req := active
	var reward := int(req.get("reward", 0))
	if player != null:
		player.set_credits(int(player.credits) + reward)
	if affinity != null:
		affinity.adjust_points(String(req.get("npc", "")), AffinityScript.REQUEST_POINTS)
	requests_done += 1
	active = {}
	var thanks := QuestDB.text_for(req, "thanks")
	request_completed.emit(req, reward, thanks)
	changed.emit()
	return {"text": thanks, "reward": reward}


## -- Town Works --

func given_to(id: String) -> Dictionary:
	return given.get(id, {})


func is_funded(id: String) -> bool:
	return funded.has(id)


func is_finished(id: String) -> bool:
	return finished.has(id)


## Puts in whatever the player carries that `id` still needs, and Credits up to what's owed.
## Returns what was taken ({} if nothing helped). A project fully funded today is built tomorrow.
func contribute(id: String, player, day: int) -> Dictionary:
	if player == null or is_finished(id) or is_funded(id) or QuestDB.project(id).is_empty():
		return {}
	var have := {}
	for item in QuestDB.needs(id):
		have[item] = int(player.inventory.count_of(item))
	var take := QuestDB.contribution(id, given_to(id), have, int(player.credits))
	if take.is_empty():
		return {}
	var record: Dictionary = given_to(id).duplicate()
	for key in take:
		if key == "credits":
			player.set_credits(int(player.credits) - int(take[key]))
		else:
			player.inventory.remove_item(String(key), int(take[key]))
		record[key] = int(record.get(key, 0)) + int(take[key])
	given[id] = record
	if QuestDB.is_funded(id, record):
		funded[id] = day
	changed.emit()
	return take


## -- Dialogue flags (docs/SOCIAL_AND_QUESTS.md §3) --

func flags(day: int) -> Dictionary:
	var out := {}
	for id in finished:
		out["project_" + String(id)] = true
		if day - int(finished[id]) < QuestDB.NEW_PROJECT_DAYS:
			out["project_%s_new" % id] = true
	if not active.is_empty():
		out["has_request_" + String(active.get("npc", ""))] = true
	return out


## -- Save/load --

func save_state() -> Dictionary:
	return {"posted": posted, "active": active, "requests_done": requests_done, "given": given,
		"funded": funded, "finished": finished, "seed": base_seed}


func load_state(data: Dictionary) -> void:
	posted = _ints(data.get("posted", {}), ["count", "posted_day", "reward"])
	active = _ints(data.get("active", {}), ["count", "posted_day", "reward", "accepted_day", "due_day", "progress"])
	requests_done = int(data.get("requests_done", 0))
	base_seed = int(data.get("seed", 0))
	given = {}
	var raw_given = data.get("given", {})
	if raw_given is Dictionary:
		for id in raw_given:
			var entry := {}
			for key in raw_given[id]:
				entry[String(key)] = int(raw_given[id][key])
			given[String(id)] = entry
	funded = _day_map(data.get("funded", {}))
	finished = _day_map(data.get("finished", {}))
	changed.emit()


static func _ints(raw, keys: Array) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var out: Dictionary = (raw as Dictionary).duplicate()
	for key in keys:
		if out.has(key):
			out[key] = int(out[key])
	return out


static func _day_map(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for id in raw:
			out[String(id)] = int(raw[id])
	return out
