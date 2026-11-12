extends "res://tests/test_case.gd"
## The authored v2 dialogue (data/dialogue.json, Milestone B 2026-10-08) against
## docs/SOCIAL_AND_QUESTS.md §3: enough lines of each kind, valid conditions and flags, text the
## UI font can draw, node targets that resolve, the service nodes, and that every NPC has
## something to say in every season, weather, time of day and tier.

const DialogueDB := preload("res://scripts/dialogue_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const QuestDB := preload("res://scripts/quest_db.gd")
const Weather := preload("res://scripts/weather.gd")
const Calendar := preload("res://scripts/calendar.gd")

## art/ui/fonts/wasteland_harvest_ui.ttf's characters (tools/font_add_glyphs.py adds the extras).
const FONT_CHARS := " !\"'()+,-./0123456789:;?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz–—‘’“”…↑↓←→%♥♡{}"
const SENTINELS: Array[String] = ["OPEN_STORE", "OPEN_RANCH_STORE", "CLINIC_HEAL", "OPEN_CLINIC_STORE",
	"SETTLER_ACCEPT", "SETTLER_REJECT", "OPEN_CARAVAN", "STORY_HOME", "STORY_SHARED"]
const FLAGS: Array[String] = ["first_week", "after_day_28", "expedition_today", "died_recently", "veteran",
	"reached_downtown", "reached_industrial", "reached_core", "raiders_hostile", "raiders_trusted",
	"player_hurt", "player_irradiated", "rich", "has_animals", "has_settlers", "birthday",
	# Milestone D (docs/LIVING_SETTLEMENT.md §6)
	"caravan_day", "festival_tomorrow", "festival_planting_day", "festival_scorch_fair",
	"festival_harvest_day", "festival_winter_gathering", "story_signal", "story_broadcast",
	"story_vault_open", "story_home", "story_shared"]
const GIFT_KINDS: Array[String] = ["loved", "liked", "neutral", "disliked", "hated", "birthday", "birthday_loved"]
const MAX_LINE := 200


func _valid_flag(flag: String) -> bool:
	if FLAGS.has(flag):
		return true
	for id in ["shop_expansion", "clinic", "watchtower", "greenhouse"]:
		if flag == "project_" + id or flag == "project_%s_new" % id:
			return true
	for npc in AffinityScript.NAMED_NPC_IDS:
		if flag == "has_request_" + npc:
			return true
	return false


func _bad_chars(text: String) -> String:
	var bad := ""
	for i in text.length():
		if not FONT_CHARS.contains(text[i]) and not bad.contains(text[i]):
			bad += text[i]
	return bad


func _check_text(where: String, text: String) -> void:
	assert_true(text.strip_edges() != "", "%s has text" % where)
	assert_true(text.length() <= MAX_LINE, "%s fits the box (%d chars)" % [where, text.length()])
	assert_eq(_bad_chars(text), "", "%s uses only the font's glyphs" % where)
	for token in ["{item}", "{season}"]:
		text = text.replace(token, "")
	assert_false(text.contains("{") or text.contains("}"), "%s has no unknown {tokens}" % where)


func test_every_named_npc_has_v2_content() -> void:
	for id in AffinityScript.NAMED_NPC_IDS:
		assert_true(DialogueDB.has_daily_lines(id), "%s has daily lines" % id)
		assert_true(DialogueDB.daily_lines(id).size() >= 18, "%s has 18+ daily lines (%d)" % [id, DialogueDB.daily_lines(id).size()])
		assert_true(DialogueDB.repeat_lines(id).size() >= 3, "%s has 3+ repeat lines" % id)
		for kind in GIFT_KINDS:
			assert_false(DialogueDB.gift_lines(id, kind).is_empty(), "%s reacts to a %s gift" % [id, kind])
		assert_false(DialogueDB.birthday(id).is_empty(), "%s has a birthday" % id)


func test_birthdays_are_real_and_distinct() -> void:
	var seen := {}
	for id in AffinityScript.NAMED_NPC_IDS:
		var b := DialogueDB.birthday(id)
		assert_true(Calendar.SEASONS.has(String(b.get("season", ""))), "%s's birthday season" % id)
		assert_true(int(b.get("day", 0)) >= 1 and int(b.get("day", 0)) <= Calendar.DAYS_PER_SEASON, "%s's birthday day" % id)
		var key := "%s %d" % [b.get("season", ""), int(b.get("day", 0))]
		assert_false(seen.has(key), "%s doesn't share a birthday (%s)" % [id, key])
		seen[key] = true


func test_conditions_use_only_known_keys_and_values() -> void:
	var once_ids := {}
	for id in AffinityScript.NAMED_NPC_IDS:
		for line in DialogueDB.daily_lines(id):
			var when: Dictionary = line.get("when", {})
			for key in when:
				var value := String(when[key])
				assert_true(DialogueDB.WHEN_KEYS.has(String(key)), "%s: known key '%s'" % [id, key])
				match String(key):
					"season":
						assert_true(Calendar.SEASONS.has(value), "%s: season %s" % [id, value])
					"weather":
						assert_true(Weather.KINDS.has(value), "%s: weather %s" % [id, value])
					"time":
						assert_true(DialogueDB.TIME_BANDS.has(value), "%s: time %s" % [id, value])
					"weekday":
						assert_true(Calendar.WEEKDAYS.has(value), "%s: weekday %s" % [id, value])
					"tier", "tier_max":
						assert_true(DialogueDB.TIER_ORDER.has(value), "%s: tier %s" % [id, value])
					"flag", "not_flag":
						assert_true(_valid_flag(value), "%s: flag %s" % [id, value])
			if bool(line.get("once", false)):
				var line_id := String(line.get("id", ""))
				assert_ne(line_id, "", "%s: a once line has an id" % id)
				assert_false(once_ids.has(line_id), "%s: once id %s is unique" % [id, line_id])
				once_ids[line_id] = true


func test_all_text_fits_and_draws() -> void:
	for id in AffinityScript.NAMED_NPC_IDS:
		var entry := DialogueDB.entry(id)
		for node_id in (entry.get("nodes", {}) as Dictionary):
			var node: Dictionary = entry["nodes"][node_id]
			_check_text("%s.%s" % [id, node_id], String(node.get("text", "")))
			for choice in node.get("choices", []):
				_check_text("%s.%s choice" % [id, node_id], String(choice.get("text", "")))
		for i in DialogueDB.daily_lines(id).size():
			_check_text("%s line %d" % [id, i], String(DialogueDB.daily_lines(id)[i].get("text", "")))
		for text in DialogueDB.repeat_lines(id):
			_check_text("%s repeat" % id, String(text))
		for kind in GIFT_KINDS:
			for text in DialogueDB.gift_lines(id, kind):
				_check_text("%s gift %s" % [id, kind], String(text))


func test_every_node_target_resolves() -> void:
	for id in AffinityScript.NAMED_NPC_IDS:
		var nodes: Dictionary = DialogueDB.entry(id).get("nodes", {})
		assert_true(nodes.has(DialogueDB.start_node_id(id)), "%s's start node exists" % id)
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			var targets: Array = []
			if node.has("next"):
				targets.append(String(node["next"]))
			for choice in node.get("choices", []):
				targets.append(String(choice.get("next", "")))
			for target in targets:
				assert_true(target == "" or nodes.has(target) or SENTINELS.has(target),
					"%s.%s -> '%s' resolves" % [id, node_id, target])


func test_service_nodes() -> void:
	assert_eq(DialogueDB.service_node_id("marta"), "shop")
	assert_eq(String(DialogueDB.dialogue_node("marta", "shop")["choices"][0]["next"]), "OPEN_STORE",
		"Marta's first service choice opens the store")
	# Silas's intro tree already has a "stock" node, so his service node has its own id.
	var silas := DialogueDB.service_node_id("rancher_silas")
	assert_ne(silas, "", "Silas has a service menu")
	assert_eq(String(DialogueDB.dialogue_node("rancher_silas", silas)["choices"][0]["next"]), "OPEN_RANCH_STORE")
	assert_eq(DialogueDB.service_node_id("doc_ama"), "clinic")
	assert_eq(DialogueDB.service_when("doc_ama"), {"flag": "project_clinic"}, "the clinic opens with the project")
	var clinic: Array = DialogueDB.dialogue_node("doc_ama", "clinic")["choices"]
	assert_eq(String(clinic[0]["next"]), "CLINIC_HEAL")
	assert_eq(String(clinic[1]["next"]), "OPEN_CLINIC_STORE")
	assert_eq(DialogueDB.service_node_id("caravan_trader"), "wares")
	assert_eq(String(DialogueDB.dialogue_node("caravan_trader", "wares")["choices"][0]["next"]), "OPEN_CARAVAN",
		"Tully's first service choice opens his stall")
	for id in ["mayor_harlan", "scout_kael", "brask", "wren"]:
		assert_eq(DialogueDB.service_node_id(id), "", "%s has no service menu" % id)


func test_nobody_is_ever_lost_for_words() -> void:
	# Every combination of season, weather, time and tier, with no flags at all, has a line.
	for id in AffinityScript.NAMED_NPC_IDS:
		for season in Calendar.SEASONS:
			for weather in Weather.KINDS:
				for time in DialogueDB.TIME_BANDS:
					for tier in DialogueDB.TIER_ORDER:
						var ctx := {"season": season, "weather": weather, "time": time, "weekday": "Mon",
							"tier": tier, "flags": {}}
						var line := DialogueDB.pick_line(DialogueDB.daily_lines(id), ctx, {}, 7)
						if line.is_empty():
							fail("%s has nothing to say: %s %s %s %s" % [id, season, weather, time, tier])
							return


func test_birthday_lines_win_on_the_day() -> void:
	for id in AffinityScript.NAMED_NPC_IDS:
		var ctx := {"season": "spring", "weather": "clear", "time": "morning", "weekday": "Mon",
			"tier": "stranger", "flags": {"birthday": true}}
		var line := DialogueDB.pick_line(DialogueDB.daily_lines(id), ctx, {}, 3)
		assert_eq(String((line.get("when", {}) as Dictionary).get("flag", "")), "birthday",
			"%s talks about their birthday on their birthday" % id)


func test_the_intro_never_treats_the_player_as_a_stranger() -> void:
	# GDD §3: the player was born here; nobody introduces themselves as if meeting a newcomer.
	for id in AffinityScript.NAMED_NPC_IDS:
		var text := String(DialogueDB.dialogue_node(id, DialogueDB.start_node_id(id)).get("text", "")).to_lower()
		for phrase in ["new face", "new farmer", "who are you", "never seen you", "you must be new"]:
			assert_false(text.contains(phrase), "%s's first words don't say '%s'" % [id, phrase])
