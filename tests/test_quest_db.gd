extends "res://tests/test_case.gd"
## scripts/quest_db.gd (Milestone B, docs/SOCIAL_AND_QUESTS.md §5-6): pools, plurals, rewards,
## picking today's request (on inline templates), project contributions and progress, and sanity
## checks on the authored data/requests.json and data/projects.json.

const QuestDB := preload("res://scripts/quest_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")

const TEMPLATES := [
	{"id": "marta_crop", "npc": "marta", "kind": "deliver", "pool": "crop", "count": [3, 6],
		"title": "Shelf Filler", "text": "Bring {npc} {count} {item} by {due}.", "thanks": "Thanks!"},
	{"id": "kael_wire", "npc": "scout_kael", "kind": "deliver", "items": ["copper_wire"], "count": [2, 2],
		"min_runs": 1, "title": "Wire", "text": "{count} {item}", "thanks": "Good."},
	{"id": "brask_hunt", "npc": "brask", "kind": "hunt", "enemy": "shambler", "count": [3, 3],
		"min_runs": 1, "title": "Thin the Herd", "text": "Put down {count} {item}.", "thanks": "Good."},
	{"id": "winter_only", "npc": "doc_ama", "kind": "deliver", "pool": "forage", "count": [1, 1],
		"season": "winter", "min_day": 10, "title": "Moss", "text": "{count} {item}", "thanks": "Ta."},
]
const PROJECTS := [
	{"id": "clinic", "name": "The Clinic Roof", "npc": "doc_ama",
		"needs": {"wood": 40, "glass": 6}, "credits": 600},
]


func after_each() -> void:
	QuestDB.reload_from_disk()


func test_pools_follow_the_season() -> void:
	var spring := QuestDB.pool_items("crop", "spring")
	assert_true(spring.has("mutant_potato") and spring.has("rain_radish"))
	assert_false(spring.has("frostroot"), "no winter crops in spring")
	assert_true(QuestDB.pool_items("crop", "summer").has("dustwheat_grain"), "crops map to their harvest item")
	assert_true(QuestDB.pool_items("forage", "winter").has("crystal_moss"))
	assert_false(QuestDB.pool_items("forage", "winter").has("wild_greens"))
	assert_eq(QuestDB.pool_items("material", "spring"), ["wood", "stone", "fiber", "hardwood"])
	assert_true(QuestDB.pool_items("nope", "spring").is_empty())


func test_plurals() -> void:
	assert_eq(QuestDB.plural("Mutant Potato"), "Mutant Potatoes")
	assert_eq(QuestDB.plural("Bloodberry"), "Bloodberries")
	assert_eq(QuestDB.plural("Rain Radish"), "Rain Radishes")
	assert_eq(QuestDB.plural("Rustvine Grapes"), "Rustvine Grapes")
	assert_eq(QuestDB.plural("Glow Melon"), "Glow Melons")
	assert_eq(QuestDB.plural("Snow Yam"), "Snow Yams")
	assert_eq(QuestDB.plural("Honey"), "Honeys", "vowel + y keeps the y")
	assert_eq(QuestDB.amount_text("mutant_potato", 5), "5 Mutant Potatoes")
	assert_eq(QuestDB.amount_text("mutant_potato", 1), "1 Mutant Potato")
	assert_eq(QuestDB.amount_text("wood", 10), "10 Wood", "mass nouns are counted, not pluralised")
	assert_eq(QuestDB.amount_text("dustwheat_grain", 6), "6 Dustwheat", "grain too")
	assert_eq(QuestDB.amount_text("dust_corn", 4), "4 Dust Corn")
	assert_eq(QuestDB.amount_text("battery", 3), "3 Batteries", "countable salvage pluralises")
	assert_eq(QuestDB.amount_text("circuit_board", 2), "2 Circuit Boards")
	for id in QuestDB.MASS_NOUNS:
		assert_true(ItemDB.has_item(id), "mass noun %s is a real item" % id)


func test_rewards() -> void:
	var value := ItemDB.sell_value("mutant_potato")
	assert_eq(QuestDB.delivery_reward("mutant_potato", 5), maxi(30, int(round(3 * value * 5 / 5.0)) * 5))
	assert_eq(QuestDB.delivery_reward("fiber", 1), QuestDB.MIN_REWARD, "never less than 30")
	assert_eq(QuestDB.delivery_reward("mutant_potato", 4) % 5, 0, "rounded to 5 Cr")


func test_eligibility_gates() -> void:
	QuestDB.use_data(TEMPLATES, PROJECTS)
	var kael := QuestDB.template("kael_wire")
	assert_false(QuestDB.eligible(kael, 5, "spring", 0), "ruins requests wait for the first run")
	assert_true(QuestDB.eligible(kael, 5, "spring", 1))
	var winter := QuestDB.template("winter_only")
	assert_false(QuestDB.eligible(winter, 12, "spring", 0), "wrong season")
	assert_false(QuestDB.eligible(winter, 5, "winter", 0), "too early")
	assert_true(QuestDB.eligible(winter, 12, "winter", 0))
	var deep := {"id": "d", "npc": "brask", "kind": "hunt", "enemy": "bloater", "count": [1, 1], "min_depth": 2}
	assert_false(QuestDB.eligible(deep, 5, "spring", 9, 1), "bloaters live deeper than you've been")
	assert_true(QuestDB.eligible(deep, 5, "spring", 9, 2))


func test_generate_is_deterministic_and_well_formed() -> void:
	QuestDB.use_data(TEMPLATES, PROJECTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var a := QuestDB.generate(3, "spring", 0, rng)
	rng.seed = 99
	assert_eq(QuestDB.generate(3, "spring", 0, rng), a, "same seed, same notice")
	assert_eq(String(a["template"]), "marta_crop", "the only eligible template on a first-week spring day")
	assert_true(QuestDB.pool_items("crop", "spring").has(String(a["item"])))
	assert_true(int(a["count"]) >= 3 and int(a["count"]) <= 6)
	assert_eq(int(a["reward"]), QuestDB.delivery_reward(String(a["item"]), int(a["count"])))
	assert_eq(int(a["posted_day"]), 3)


func test_generate_hunts_and_skips_the_last_poster() -> void:
	QuestDB.use_data(TEMPLATES, PROJECTS)
	var rng := RandomNumberGenerator.new()
	var npcs := {}
	for i in 40:
		rng.seed = i
		var req := QuestDB.generate(3, "spring", 2, rng, "marta")
		npcs[req["npc"]] = true
		if req["kind"] == "hunt":
			assert_eq(String(req["enemy"]), "shambler")
			assert_eq(int(req["reward"]), QuestDB.HUNT_REWARD_PER_KILL * int(req["count"]))
	assert_false(npcs.has("marta"), "Marta doesn't post twice running when others can")
	assert_true(npcs.has("brask") and npcs.has("scout_kael"))
	QuestDB.use_data([], PROJECTS)
	assert_eq(QuestDB.generate(3, "spring", 0, rng), {}, "no templates, no notice")


func test_text_tokens() -> void:
	QuestDB.use_data(TEMPLATES, PROJECTS)
	var req := {"template": "marta_crop", "npc": "marta", "kind": "deliver", "item": "mutant_potato", "count": 5}
	# Day 4 is a Thursday (day 1 is a Monday).
	assert_eq(QuestDB.text_for(req, "text", 4), "Bring Marta 5 Mutant Potatoes by Thursday.")
	var hunt := {"template": "brask_hunt", "npc": "brask", "kind": "hunt", "enemy": "shambler", "count": 3}
	assert_eq(QuestDB.text_for(hunt, "text"), "Put down 3 shamblers.")
	var one := {"template": "brask_hunt", "npc": "brask", "kind": "hunt", "enemy": "rad_hound", "count": 1}
	assert_eq(QuestDB.text_for(one, "text"), "Put down 1 rad-hound.")
	assert_eq(QuestDB.title_of(req), "Shelf Filler")


func test_project_contribution_math() -> void:
	QuestDB.use_data(TEMPLATES, PROJECTS)
	assert_eq(QuestDB.remaining("clinic", {}), {"wood": 40, "glass": 6, "credits": 600})
	var take := QuestDB.contribution("clinic", {}, {"wood": 25, "glass": 9, "stone": 50}, 1000)
	assert_eq(take, {"wood": 25, "glass": 6, "credits": 600}, "takes what's owed, no more, and nothing unneeded")
	var given := {"wood": 25, "glass": 6, "credits": 600}
	assert_eq(QuestDB.remaining("clinic", given), {"wood": 15})
	assert_false(QuestDB.is_funded("clinic", given))
	assert_eq(QuestDB.contribution("clinic", given, {"stone": 5}, 0), {}, "nothing that helps")
	given["wood"] = 40
	assert_true(QuestDB.is_funded("clinic", given))
	assert_false(QuestDB.is_funded("nope", {}), "an unknown project is never funded")


func test_project_progress() -> void:
	QuestDB.use_data(TEMPLATES, PROJECTS)
	assert_eq(QuestDB.progress("clinic", {}), 0.0)
	assert_eq(QuestDB.progress("clinic", {"wood": 40, "glass": 6, "credits": 600}), 1.0)
	var half_credits := QuestDB.progress("clinic", {"credits": 300})
	assert_true(half_credits > 0.0 and half_credits < 1.0)
	assert_eq(QuestDB.progress("clinic", {"wood": 999, "glass": 99, "credits": 9999}), 1.0, "over-giving caps")


func test_authored_requests_are_valid() -> void:
	QuestDB.reload_from_disk()
	var templates := QuestDB.templates()
	assert_true(templates.size() >= 14, "about 20 templates (%d)" % templates.size())
	var ids := {}
	var by_npc := {}
	for t in templates:
		var id := String(t["id"])
		assert_false(ids.has(id), "unique template id %s" % id)
		ids[id] = true
		assert_true(AffinityScript.is_named_npc(String(t["npc"])), "%s: a named npc" % id)
		by_npc[String(t["npc"])] = true
		var kind := String(t["kind"])
		assert_true(kind == "deliver" or kind == "hunt", "%s: kind" % id)
		if kind == "hunt":
			assert_true(QuestDB.HUNT_ENEMIES.has(String(t["enemy"])) or String(t["enemy"]) == "any",
				"%s: huntable enemy (never raiders)" % id)
		elif t.has("items"):
			for item in t["items"]:
				assert_true(ItemDB.has_item(String(item)), "%s: item %s exists" % [id, item])
		else:
			assert_true(String(t["pool"]) in ["crop", "forage", "material", "salvage", "cooked", "artisan"],
				"%s: known pool" % id)
		assert_true(String(t.get("title", "")).length() <= 24, "%s: title fits" % id)
		assert_true(String(t.get("text", "")) != "" and String(t.get("thanks", "")) != "", "%s: has text" % id)
	for npc_id in AffinityScript.NAMED_NPC_IDS:
		assert_true(by_npc.has(npc_id), "%s posts requests" % npc_id)


func test_authored_projects_match_the_spec() -> void:
	QuestDB.reload_from_disk()
	assert_eq(QuestDB.project_ids(), ["shop_expansion", "clinic", "watchtower", "greenhouse"])
	assert_eq(QuestDB.needs("clinic"), {"wood": 40, "stone": 40, "glass": 6, "cloth_scrap": 10, "copper_wire": 3})
	assert_eq(QuestDB.credits_needed("greenhouse"), 1500)
	for id in QuestDB.project_ids():
		var p := QuestDB.project(id)
		for field in ["name", "summary", "reward", "done"]:
			assert_ne(String(p.get(field, "")), "", "%s has a %s" % [id, field])
		for item in QuestDB.needs(id):
			assert_true(ItemDB.has_item(item), "%s needs a real item (%s)" % [id, item])


func test_hunts_only_post_where_their_quarry_lives() -> void:
	# A hunt for something the player can't meet yet would be an impossible request: its min_depth
	# must reach the first district whose enemy mix (scripts/ruins_gen.gd) includes it.
	var RuinsGen = load("res://scripts/ruins_gen.gd")
	QuestDB.reload_from_disk()
	for t in QuestDB.templates():
		if String(t["kind"]) != "hunt" or String(t.get("enemy", "any")) == "any":
			continue
		var enemy := String(t["enemy"])
		var first := -1
		for i in RuinsGen.ENEMY_MIX.size():
			if (RuinsGen.ENEMY_MIX[i] as Dictionary).has(enemy):
				first = i + 1
				break
		assert_true(first != -1, "%s: %s spawns somewhere" % [t["id"], enemy])
		assert_true(maxi(int(t.get("min_depth", 1)), 1) >= first,
			"%s waits for depth %d, where %s first appears" % [t["id"], first, enemy])
