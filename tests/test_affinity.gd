extends "res://tests/test_case.gd"
## scripts/affinity.gd: friendship points and hearts, tiers, the once-a-day talk award, gifts
## (daily and weekly limits, birthdays, discovered tastes), once-only lines, and the save round
## trip through scripts/save_data.gd (including a pre-points save). Reworked for Milestone B
## (2026-10-08, docs/SOCIAL_AND_QUESTS.md §2).
##
## Affinity is a Node with no scene; each test makes one and frees it (an unfreed Node leaks an
## ObjectDB instance, which the runner only reports as a trailing warning).

const AffinityScript := preload("res://scripts/affinity.gd")
const SaveData := preload("res://scripts/save_data.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const HARLAN := "mayor_harlan"
const MARTA := "marta"
const HEART := AffinityScript.POINTS_PER_HEART


func _make_affinity() -> Node:
	return AffinityScript.new()


## -- Scope --

func test_named_npc_ids_match_the_authored_layout_roster() -> void:
	# affinity.gd keeps its own copy of the named ids; pin it to the layouts' rosters.
	var authored: Array[String] = []
	for entry in LayoutCommon.TOWN_NPCS:
		authored.append(String(entry["id"]))
	for entry in LayoutCommon.RANCH_NPCS:
		authored.append(String(entry["id"]))
	authored.sort()
	var declared: Array[String] = []
	for id in AffinityScript.NAMED_NPC_IDS:
		declared.append(String(id))
	declared.sort()
	assert_eq(declared, authored, "NAMED_NPC_IDS is exactly TOWN_NPCS + RANCH_NPCS")


func test_is_named_npc_excludes_settlers_and_unknown_ids() -> void:
	assert_true(AffinityScript.is_named_npc(HARLAN))
	assert_true(AffinityScript.is_named_npc("doc_ama"))
	assert_false(AffinityScript.is_named_npc("settler_1"), "settlers have no relationship track")
	assert_false(AffinityScript.is_named_npc("nobody"))
	assert_false(AffinityScript.is_named_npc(""))


## -- Points, hearts, clamping --

func test_unknown_npc_starts_at_zero() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.value_for(HARLAN), 0)
	assert_eq(affinity.points_for("nobody"), 0)
	affinity.free()


func test_hearts_are_whole_multiples_of_points() -> void:
	assert_eq(AffinityScript.hearts_for_points(0), 0)
	assert_eq(AffinityScript.hearts_for_points(HEART - 1), 0, "249 points is not yet a heart")
	assert_eq(AffinityScript.hearts_for_points(HEART), 1)
	assert_eq(AffinityScript.hearts_for_points(10 * HEART), 10)
	assert_eq(AffinityScript.hearts_for_points(99999), 10, "clamped at ten hearts")
	assert_eq(AffinityScript.hearts_for_points(-50), 0)


func test_adjust_moves_whole_hearts_and_adjust_points_moves_points() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 3)
	assert_eq(affinity.value_for(HARLAN), 3)
	assert_eq(affinity.points_for(HARLAN), 3 * HEART)
	affinity.adjust_points(HARLAN, 100)
	assert_eq(affinity.value_for(HARLAN), 3, "100 points don't make a heart")
	affinity.adjust_points(HARLAN, 150)
	assert_eq(affinity.value_for(HARLAN), 4)
	affinity.adjust(HARLAN, -4)
	assert_eq(affinity.points_for(HARLAN), 0)
	affinity.free()


func test_points_clamp_to_the_track() -> void:
	var affinity := _make_affinity()
	affinity.adjust_points(HARLAN, 99999)
	assert_eq(affinity.points_for(HARLAN), AffinityScript.MAX_POINTS)
	assert_eq(affinity.value_for(HARLAN), AffinityScript.MAX_AFFINITY)
	affinity.adjust_points(HARLAN, -99999)
	assert_eq(affinity.points_for(HARLAN), 0)
	affinity.free()


func test_affinity_changed_fires_only_on_a_real_change_with_hearts() -> void:
	var affinity := _make_affinity()
	var events: Array[Array] = []
	affinity.affinity_changed.connect(
		func(npc_id: String, value: int) -> void: events.append([npc_id, value]))
	affinity.adjust(HARLAN, 2)
	assert_eq(events, [[HARLAN, 2]], "a real change emits the new heart count")
	affinity.adjust_points(HARLAN, 10)
	assert_eq(events.size(), 2, "a points change emits even within a heart")
	affinity.adjust(HARLAN, 99)
	affinity.adjust(HARLAN, 3)
	assert_eq(events.size(), 3, "a push against the ceiling emits nothing")
	affinity.adjust_points(HARLAN, 0)
	assert_eq(events.size(), 3, "a zero delta emits nothing")
	affinity.free()


func test_a_noop_adjust_writes_nothing() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 0)
	affinity.adjust_points(MARTA, -30)
	assert_eq(affinity.save_state()["points"], {}, "no zero entries are saved")
	affinity.free()


## -- Tiers --

func test_tier_boundaries_are_exact() -> void:
	assert_eq(AffinityScript.tier_for_value(0), AffinityScript.TIER_STRANGER)
	assert_eq(AffinityScript.tier_for_value(1), AffinityScript.TIER_STRANGER)
	assert_eq(AffinityScript.tier_for_value(2), AffinityScript.TIER_ACQUAINTANCE)
	assert_eq(AffinityScript.tier_for_value(4), AffinityScript.TIER_ACQUAINTANCE)
	assert_eq(AffinityScript.tier_for_value(5), AffinityScript.TIER_FRIEND)
	assert_eq(AffinityScript.tier_for_value(7), AffinityScript.TIER_FRIEND)
	assert_eq(AffinityScript.tier_for_value(8), AffinityScript.TIER_CLOSE)
	assert_eq(AffinityScript.tier_for_value(10), AffinityScript.TIER_CLOSE)
	assert_eq(AffinityScript.tier_for_value(-5), AffinityScript.TIER_STRANGER)
	assert_eq(AffinityScript.tier_for_value(999), AffinityScript.TIER_CLOSE)
	assert_eq(AffinityScript.tier_rank("friend"), 2)
	assert_eq(AffinityScript.tier_rank("nope"), -1)


func test_tier_for_reads_live_hearts() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.tier_for(MARTA), AffinityScript.TIER_STRANGER)
	affinity.adjust(MARTA, 5)
	assert_eq(affinity.tier_for(MARTA), AffinityScript.TIER_FRIEND)
	affinity.free()


## -- The talk award --

func test_talk_awards_once_a_day() -> void:
	var affinity := _make_affinity()
	assert_true(affinity.try_award_talk(HARLAN, 3))
	assert_eq(affinity.points_for(HARLAN), AffinityScript.TALK_POINTS)
	assert_false(affinity.try_award_talk(HARLAN, 3), "no repeat-talk farming")
	assert_eq(affinity.points_for(HARLAN), AffinityScript.TALK_POINTS)
	assert_true(affinity.talked_today(HARLAN, 3))
	assert_true(affinity.try_award_talk(HARLAN, 4), "a new day, a new chat")
	assert_eq(affinity.points_for(HARLAN), 2 * AffinityScript.TALK_POINTS)
	affinity.free()


func test_talk_is_slow_on_its_own() -> void:
	# A heart from talking alone takes about two weeks (Stardew's pace), not one chat.
	assert_true(HEART / AffinityScript.TALK_POINTS >= 10,
		"a heart takes at least ten days of talk (%d)" % (HEART / AffinityScript.TALK_POINTS))


func test_talk_cap_is_per_npc_and_named_only() -> void:
	var affinity := _make_affinity()
	assert_true(affinity.try_award_talk(HARLAN, 5))
	assert_true(affinity.try_award_talk(MARTA, 5), "Harlan's chat doesn't use up Marta's")
	assert_false(affinity.try_award_talk("settler_1", 5))
	assert_eq(affinity.last_talked_day("settler_1"), -1, "no bookkeeping for settlers")
	assert_eq(affinity.last_talked_day("nobody"), -1)
	affinity.free()


## -- Gifts --

func test_gift_points_by_reaction_and_birthday() -> void:
	assert_eq(AffinityScript.gift_points("loved", false), 80)
	assert_eq(AffinityScript.gift_points("liked", false), 45)
	assert_eq(AffinityScript.gift_points("neutral", false), 20)
	assert_eq(AffinityScript.gift_points("disliked", false), -20)
	assert_eq(AffinityScript.gift_points("hated", false), -40)
	assert_eq(AffinityScript.gift_points("loved", true), 400, "birthday x5")
	assert_eq(AffinityScript.gift_points("hated", true), -200, "a hated birthday gift stings")


func test_weeks_run_monday_to_sunday() -> void:
	assert_eq(AffinityScript.week_of(1), 0)
	assert_eq(AffinityScript.week_of(7), 0)
	assert_eq(AffinityScript.week_of(8), 1)
	assert_eq(AffinityScript.week_of(28), 3)


func test_one_gift_a_day_two_a_week() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.gift_refusal(MARTA, "rain_radish", 1, false), "")
	affinity.give_gift(MARTA, "rain_radish", 1, false)
	assert_eq(affinity.gift_refusal(MARTA, "rain_radish", 1, false), "today")
	assert_eq(affinity.gift_refusal(HARLAN, "rain_radish", 1, false), "", "per NPC")
	affinity.give_gift(MARTA, "rain_radish", 2, false)
	assert_eq(affinity.gifts_this_week(MARTA, 3), 2)
	assert_eq(affinity.gift_refusal(MARTA, "rain_radish", 3, false), "week")
	assert_eq(affinity.gift_refusal(MARTA, "rain_radish", 3, true), "", "a birthday ignores the week")
	assert_eq(affinity.gift_refusal(MARTA, "rain_radish", 8, false), "", "a new week")
	affinity.free()


func test_birthday_gift_does_not_use_up_the_week() -> void:
	var affinity := _make_affinity()
	affinity.give_gift(MARTA, "rain_radish", 1, true)
	assert_eq(affinity.gifts_this_week(MARTA, 2), 0)
	affinity.free()


func test_gift_refusal_rejects_ungiftable_and_unnamed() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.gift_refusal(MARTA, "hoe", 1, false), "not_giftable")
	assert_eq(affinity.gift_refusal(MARTA, "seed_rain_radish", 1, false), "not_giftable")
	assert_eq(affinity.gift_refusal("settler_1", "rain_radish", 1, false), "not_named")
	affinity.free()


func test_give_gift_scores_records_and_remembers_the_taste() -> void:
	var affinity := _make_affinity()
	var given: Array = []
	affinity.gift_given.connect(func(npc_id, item_id, reaction, points): given.append([npc_id, item_id, reaction, points]))
	var result: Dictionary = affinity.give_gift(MARTA, "rain_radish", 4, false)
	var expected := AffinityScript.gift_points(String(result["reaction"]), false)
	assert_eq(int(result["points"]), expected)
	assert_eq(affinity.points_for(MARTA), maxi(expected, 0), "negative points clamp at zero")
	assert_eq(affinity.known_gifts(MARTA), {"rain_radish": String(result["reaction"])})
	assert_eq(given.size(), 1)
	assert_true(affinity.gifted_today(MARTA, 4))
	assert_false(affinity.gifted_today(MARTA, 5))
	affinity.free()


## -- Once-only lines --

func test_seen_lines_are_remembered() -> void:
	var affinity := _make_affinity()
	assert_false(affinity.has_seen_line("harlan_first_snow"))
	affinity.mark_line_seen("harlan_first_snow")
	affinity.mark_line_seen("")
	assert_true(affinity.has_seen_line("harlan_first_snow"))
	assert_eq(affinity.save_state()["seen_lines"], ["harlan_first_snow"], "empty ids aren't stored")
	affinity.free()


## -- Save/load --

func test_encode_affinity_normalises_floats_to_ints() -> void:
	var encoded := SaveData.encode_affinity({"marta": 400.0}, {"marta": 7.0},
		{"last_gift_day": {"marta": 6.0}, "gift_week": {"marta": [0.0, 2.0]},
		"known_gifts": {"marta": {"glow_melon": "loved"}}, "seen_lines": ["x"]})
	assert_eq(encoded["points"], {"marta": 400})
	assert_eq(encoded["last_talked_day"], {"marta": 7})
	assert_eq(encoded["last_gift_day"], {"marta": 6})
	assert_eq(encoded["gift_week"], {"marta": [0, 2]})
	assert_eq(encoded["known_gifts"], {"marta": {"glow_melon": "loved"}})
	assert_eq(encoded["seen_lines"], ["x"])


func test_decode_affinity_defaults_empty_for_an_old_save() -> void:
	var decoded := SaveData.decode_affinity({})
	assert_eq(decoded["points"], {})
	assert_eq(decoded["last_talked_day"], {})
	assert_eq(decoded["known_gifts"], {})
	assert_eq(decoded["seen_lines"], [])


func test_a_pre_points_save_keeps_its_hearts() -> void:
	# Saves from before 2026-10-08 stored whole hearts under "values".
	var decoded := SaveData.decode_affinity({"values": {"marta": 3}, "last_talked_day": {"marta": 9}})
	assert_eq(decoded["points"], {"marta": 3 * HEART})
	var affinity := _make_affinity()
	affinity.load_state({"values": {"marta": 3}, "last_talked_day": {"marta": 9}})
	assert_eq(affinity.value_for(MARTA), 3)
	assert_eq(affinity.last_talked_day(MARTA), 9)
	affinity.free()


func test_round_trip_through_json_preserves_everything() -> void:
	var affinity := _make_affinity()
	affinity.try_award_talk(HARLAN, 4)
	affinity.give_gift(MARTA, "rain_radish", 4, false)
	affinity.adjust(MARTA, 5)
	affinity.mark_line_seen("once_a")
	var text := JSON.stringify(affinity.save_state())
	var restored := _make_affinity()
	restored.load_state(JSON.parse_string(text))
	assert_eq(restored.points_for(HARLAN), affinity.points_for(HARLAN))
	assert_eq(restored.points_for(MARTA), affinity.points_for(MARTA))
	assert_false(restored.try_award_talk(HARLAN, 4), "the daily cap survives a reload")
	assert_eq(restored.gift_refusal(MARTA, "rain_radish", 4, false), "today", "so does today's gift")
	assert_eq(restored.gifts_this_week(MARTA, 5), 1)
	assert_eq(restored.known_gifts(MARTA), affinity.known_gifts(MARTA))
	assert_true(restored.has_seen_line("once_a"))
	affinity.free()
	restored.free()


func test_load_state_with_empty_data_leaves_a_fresh_track() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 5)
	affinity.load_state({})
	assert_eq(affinity.value_for(HARLAN), 0)
	assert_eq(affinity.last_talked_day(HARLAN), -1)
	affinity.free()


func test_load_state_reclamps_out_of_range_points() -> void:
	var affinity := _make_affinity()
	affinity.load_state(SaveData.encode_affinity({HARLAN: 999999, MARTA: -40}, {}))
	assert_eq(affinity.points_for(HARLAN), AffinityScript.MAX_POINTS)
	assert_eq(affinity.points_for(MARTA), 0)
	assert_eq(affinity.tier_for(HARLAN), AffinityScript.TIER_CLOSE)
	affinity.free()
