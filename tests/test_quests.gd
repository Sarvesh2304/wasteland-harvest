extends "res://tests/test_case.gd"
## scripts/quests.gd (Milestone B): posting, accepting, handing in, hunts, lapsing, Town Works
## contributions and overnight completion, dialogue flags, and the save round trip. Runs on inline
## templates/projects (QuestDB.use_data) with a stand-in player (an inventory and Credits).

const QuestsScript := preload("res://scripts/quests.gd")
const QuestDB := preload("res://scripts/quest_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const Inventory := preload("res://scripts/inventory.gd")

const TEMPLATES := [
	{"id": "marta_wire", "npc": "marta", "kind": "deliver", "items": ["copper_wire"], "count": [3, 3],
		"title": "Wire", "text": "Bring {npc} {count} {item}.", "thanks": "Lovely, thank you."},
]
const HUNT := [
	{"id": "brask_hunt", "npc": "brask", "kind": "hunt", "enemy": "shambler", "count": [2, 2],
		"title": "Thin the Herd", "text": "Put down {count} {item}.", "thanks": "Good."},
]
const PROJECTS := [
	{"id": "clinic", "name": "The Clinic Roof", "npc": "doc_ama", "needs": {"wood": 10, "glass": 2}, "credits": 100},
]


class FakePlayer:
	var inventory = preload("res://scripts/inventory.gd").new()
	var credits := 0

	func set_credits(value: int) -> void:
		credits = value


func after_each() -> void:
	QuestDB.reload_from_disk()


func _make(templates: Array = TEMPLATES) -> Node:
	QuestDB.use_data(templates, PROJECTS)
	var quests: Node = QuestsScript.new()
	quests.new_game(1234, 1, "spring")
	return quests


func test_new_game_posts_a_notice() -> void:
	var quests := _make()
	assert_eq(String(quests.posted.get("template", "")), "marta_wire")
	assert_true(quests.can_accept())
	assert_true(quests.active.is_empty())
	quests.free()


func test_accept_moves_the_notice_and_sets_the_due_day() -> void:
	var quests := _make()
	assert_true(quests.accept(1))
	assert_true(quests.posted.is_empty())
	assert_eq(int(quests.active["due_day"]), 1 + QuestDB.DUE_DAYS)
	assert_eq(quests.days_left(1), 2)
	assert_false(quests.accept(1), "one request at a time")
	assert_true(quests.is_requester("marta"))
	assert_false(quests.is_requester("brask"))
	quests.free()


func test_handing_in_pays_and_befriends() -> void:
	var quests := _make()
	var affinity: Node = AffinityScript.new()
	quests.affinity = affinity
	quests.accept(1)
	var player := FakePlayer.new()
	player.inventory.add_item("copper_wire", 2)
	assert_eq(quests.try_deliver("marta", player), {}, "not enough yet")
	player.inventory.add_item("copper_wire", 2)
	assert_eq(quests.try_deliver("brask", player), {}, "the wrong person")
	var reward := int(quests.active["reward"])
	var got: Dictionary = quests.try_deliver("marta", player)
	assert_eq(String(got["text"]), "Lovely, thank you.")
	assert_eq(int(got["reward"]), reward)
	assert_eq(player.credits, reward)
	assert_eq(player.inventory.count_of("copper_wire"), 1, "only what was asked for is taken")
	assert_eq(affinity.points_for("marta"), AffinityScript.REQUEST_POINTS)
	assert_true(quests.active.is_empty())
	assert_eq(quests.requests_done, 1)
	quests.free()
	affinity.free()


func test_a_request_lapses_after_its_due_day() -> void:
	var quests := _make()
	var lapsed: Array = []
	quests.request_expired.connect(func(req): lapsed.append(req))
	quests.accept(1)
	quests.on_day_started(3, "spring", 0)
	assert_false(quests.active.is_empty(), "still due on day 3")
	quests.on_day_started(4, "spring", 0)
	assert_true(quests.active.is_empty(), "gone on day 4")
	assert_eq(lapsed.size(), 1)
	quests.free()


func test_a_new_notice_each_morning() -> void:
	var quests := _make()
	var first: Dictionary = quests.posted
	quests.on_day_started(2, "spring", 0)
	assert_eq(int(quests.posted["posted_day"]), 2)
	quests.on_day_started(2, "spring", 0)
	assert_eq(int(quests.posted["posted_day"]), 2, "the same morning twice doesn't repost")
	assert_eq(int(first["posted_day"]), 1)
	quests.free()


func test_postings_are_reproducible_from_the_seed() -> void:
	var a := _make()
	var b := _make()
	a.on_day_started(5, "spring", 0)
	b.on_day_started(5, "spring", 0)
	assert_eq(a.posted, b.posted, "same seed and day, same notice (a reload can't reroll it)")
	a.free()
	b.free()


func test_hunts_finish_on_the_last_kill() -> void:
	var quests := _make(HUNT)
	var player := FakePlayer.new()
	var done: Array = []
	quests.request_completed.connect(func(req, reward, thanks): done.append([reward, thanks]))
	quests.accept(1)
	quests.on_enemy_killed("runner", player)
	assert_eq(int(quests.active["progress"]), 0, "the wrong kind doesn't count")
	quests.on_enemy_killed("shambler", player)
	assert_eq(int(quests.active["progress"]), 1)
	quests.on_enemy_killed("shambler", player)
	assert_true(quests.active.is_empty())
	assert_eq(done, [[2 * QuestDB.HUNT_REWARD_PER_KILL, "Good."]])
	assert_eq(player.credits, 2 * QuestDB.HUNT_REWARD_PER_KILL)
	quests.free()


func test_contributions_fund_then_finish_overnight() -> void:
	var quests := _make()
	var player := FakePlayer.new()
	player.inventory.add_item("wood", 6)
	player.inventory.add_item("glass", 5)
	player.credits = 40
	var took: Dictionary = quests.contribute("clinic", player, 3)
	assert_eq(took, {"wood": 6, "glass": 2, "credits": 40})
	assert_eq(player.inventory.count_of("glass"), 3)
	assert_eq(player.credits, 0)
	assert_false(quests.is_funded("clinic"))
	assert_eq(quests.contribute("clinic", player, 3), {}, "nothing more to give")
	player.inventory.add_item("wood", 10)
	player.credits = 500
	quests.contribute("clinic", player, 4)
	assert_true(quests.is_funded("clinic"))
	assert_eq(player.credits, 440, "only what's owed")
	assert_eq(player.inventory.count_of("wood"), 6)
	assert_eq(quests.contribute("clinic", player, 4), {}, "a funded project takes nothing more")
	assert_eq(quests.on_day_started(4, "spring", 0), [], "built overnight, not the same day")
	assert_eq(quests.on_day_started(5, "spring", 0), ["clinic"])
	assert_true(quests.is_finished("clinic"))
	assert_false(quests.is_funded("clinic"))
	assert_eq(quests.on_day_started(6, "spring", 0), [], "finished once")
	quests.free()


func test_dialogue_flags() -> void:
	var quests := _make()
	quests.accept(1)
	assert_eq(quests.flags(1), {"has_request_marta": true})
	quests.finished["clinic"] = 5
	var flags: Dictionary = quests.flags(7)
	assert_true(flags.has("project_clinic") and flags.has("project_clinic_new"))
	assert_false(quests.flags(8).has("project_clinic_new"), "news for three days")
	assert_true(quests.flags(8).has("project_clinic"))
	quests.free()


func test_save_round_trip_through_json() -> void:
	var quests := _make()
	quests.accept(1)
	var player := FakePlayer.new()
	player.inventory.add_item("wood", 4)
	quests.contribute("clinic", player, 1)
	quests.finished["shop_expansion"] = 2
	var text := JSON.stringify(quests.save_state())
	var restored: Node = QuestsScript.new()
	restored.load_state(JSON.parse_string(text))
	assert_eq(restored.active, quests.active)
	assert_eq(int(restored.active["due_day"]), 3, "ints come back as ints")
	assert_eq(restored.given_to("clinic"), {"wood": 4})
	assert_true(restored.is_finished("shop_expansion"))
	assert_eq(restored.base_seed, 1234)
	restored.on_day_started(2, "spring", 0)
	quests.on_day_started(2, "spring", 0)
	assert_eq(restored.posted, quests.posted, "the board carries on identically after a reload")
	quests.free()
	restored.free()
