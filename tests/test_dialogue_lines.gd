extends "res://tests/test_case.gd"
## scripts/dialogue_db.gd's v2 daily-line rules (Milestone B, docs/SOCIAL_AND_QUESTS.md §3): time
## bands, `when` matching, priority, weighting, once-only lines, determinism and tokens. Pure
## functions on inline data; the authored content itself is covered by test_dialogue_db.gd.

const DialogueDB := preload("res://scripts/dialogue_db.gd")


func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var ctx := {"season": "spring", "weather": "clear", "time": "morning", "weekday": "Mon",
		"tier": "stranger", "flags": {}}
	for key in overrides:
		ctx[key] = overrides[key]
	return ctx


func test_time_bands() -> void:
	assert_eq(DialogueDB.time_band(6 * 60), "morning")
	assert_eq(DialogueDB.time_band(11 * 60 + 59), "morning")
	assert_eq(DialogueDB.time_band(12 * 60), "afternoon")
	assert_eq(DialogueDB.time_band(17 * 60), "evening")
	assert_eq(DialogueDB.time_band(21 * 60), "night")
	assert_eq(DialogueDB.time_band(60), "night", "1 AM is still night")
	assert_eq(DialogueDB.time_band(5 * 60 + 59), "night")


func test_when_matches_each_key() -> void:
	assert_true(DialogueDB.when_matches({}, _ctx()), "no conditions always match")
	assert_true(DialogueDB.when_matches({"season": "spring", "time": "morning"}, _ctx()))
	assert_false(DialogueDB.when_matches({"season": "winter"}, _ctx()))
	assert_false(DialogueDB.when_matches({"weather": "rain"}, _ctx()))
	assert_true(DialogueDB.when_matches({"weekday": "Mon"}, _ctx()))
	assert_true(DialogueDB.when_matches({"flag": "veteran"}, _ctx({"flags": {"veteran": true}})))
	assert_false(DialogueDB.when_matches({"flag": "veteran"}, _ctx()))
	assert_true(DialogueDB.when_matches({"not_flag": "veteran"}, _ctx()))
	assert_false(DialogueDB.when_matches({"not_flag": "veteran"}, _ctx({"flags": {"veteran": true}})))


func test_tier_is_a_minimum_and_tier_max_a_maximum() -> void:
	assert_false(DialogueDB.when_matches({"tier": "friend"}, _ctx({"tier": "acquaintance"})))
	assert_true(DialogueDB.when_matches({"tier": "friend"}, _ctx({"tier": "friend"})))
	assert_true(DialogueDB.when_matches({"tier": "friend"}, _ctx({"tier": "close"})))
	assert_true(DialogueDB.when_matches({"tier_max": "acquaintance"}, _ctx({"tier": "stranger"})))
	assert_false(DialogueDB.when_matches({"tier_max": "acquaintance"}, _ctx({"tier": "friend"})))


func test_unknown_keys_never_match() -> void:
	assert_false(DialogueDB.when_matches({"seasn": "spring"}, _ctx()),
		"a typo can't turn a line into an everyday line")


func test_pick_line_filters_and_is_deterministic() -> void:
	var lines := [
		{"text": "generic"},
		{"text": "rainy", "when": {"weather": "rain"}},
		{"text": "winter", "when": {"season": "winter"}},
	]
	for seed_value in 50:
		var picked := DialogueDB.pick_line(lines, _ctx(), {}, seed_value)
		assert_eq(String(picked["text"]), "generic", "only the generic line matches a clear spring day")
	var a := DialogueDB.pick_line(lines, _ctx({"weather": "rain"}), {}, 7)
	var b := DialogueDB.pick_line(lines, _ctx({"weather": "rain"}), {}, 7)
	assert_eq(a, b, "same seed, same line")
	assert_eq(DialogueDB.pick_line([], _ctx(), {}, 1), {}, "nothing to say")


func test_specific_lines_are_weighted_up() -> void:
	# generic (weight 1) vs a one-condition line (weight 3): the rain line should win about 3/4.
	var lines := [{"text": "generic"}, {"text": "rainy", "when": {"weather": "rain"}}]
	var rainy := 0
	for seed_value in 400:
		if String(DialogueDB.pick_line(lines, _ctx({"weather": "rain"}), {}, seed_value)["text"]) == "rainy":
			rainy += 1
	assert_eq(rainy, 300, "exactly 3 in 4 seeds pick the specific line")


func test_priority_beats_everything() -> void:
	var lines := [
		{"text": "generic"},
		{"text": "rainy", "when": {"weather": "rain"}},
		{"text": "birthday", "when": {"flag": "birthday"}, "priority": 10},
		{"text": "project", "when": {"flag": "project_clinic_new"}, "priority": 5},
	]
	var ctx := _ctx({"weather": "rain", "flags": {"birthday": true, "project_clinic_new": true}})
	for seed_value in 20:
		assert_eq(String(DialogueDB.pick_line(lines, ctx, {}, seed_value)["text"]), "birthday")
	ctx["flags"].erase("birthday")
	assert_eq(String(DialogueDB.pick_line(lines, ctx, {}, 3)["text"]), "project")


func test_once_lines_play_once() -> void:
	var lines := [{"text": "generic"}, {"id": "first_snow", "text": "snow!", "when": {"weather": "snow"},
		"once": true, "priority": 3}]
	var ctx := _ctx({"weather": "snow"})
	assert_eq(String(DialogueDB.pick_line(lines, ctx, {}, 1)["text"]), "snow!")
	assert_eq(String(DialogueDB.pick_line(lines, ctx, {"first_snow": true}, 1)["text"]), "generic",
		"seen once, never again")


func test_daily_seed_is_stable_and_varies() -> void:
	assert_eq(DialogueDB.daily_seed("marta", 5), DialogueDB.daily_seed("marta", 5))
	assert_ne(DialogueDB.daily_seed("marta", 5), DialogueDB.daily_seed("marta", 6), "a new day")
	assert_ne(DialogueDB.daily_seed("marta", 5), DialogueDB.daily_seed("brask", 5), "a different face")
	assert_ne(DialogueDB.daily_seed("marta", 5), DialogueDB.daily_seed("marta", 5, "gift"), "salted")
	assert_true(DialogueDB.daily_seed("marta", 5) >= 0)


func test_pick_text_and_fill() -> void:
	assert_eq(DialogueDB.pick_text([], 3), "")
	assert_eq(DialogueDB.pick_text(["a", "b"], 3), "b")
	assert_eq(DialogueDB.fill("A {item} for {npc}.", {"item": "Glow Melon", "npc": "Marta"}),
		"A Glow Melon for Marta.")
	assert_eq(DialogueDB.fill("No tokens.", {"item": "x"}), "No tokens.")
