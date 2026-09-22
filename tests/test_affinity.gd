extends "res://tests/test_case.gd"
## Phase 7 Stage 3 (relationship/affinity system): scripts/affinity.gd's clamped adjust, the pure
## tier bucketing Stage 5 will author against, the once-per-day-per-NPC talk tick, and the
## save/load round trip through scripts/save_data.gd's encode_affinity/decode_affinity.
##
## Affinity is a Node (a singleton-per-Main, like settlers.gd/animals.gd) but needs no scene: it
## connects to nothing and ticks nothing, so every test here instantiates it directly and drives
## its methods — the same "real node, no scene file" shape tests/test_animals.gd uses. Every such
## instance is .free()d at the end of its test: a Node left unfreed leaks an ObjectDB instance
## and the headless runner reports it only as a trailing warning, not a failure.

const AffinityScript := preload("res://scripts/affinity.gd")
const SaveData := preload("res://scripts/save_data.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const HARLAN := "mayor_harlan"
const MARTA := "marta"


func _make_affinity() -> Node:
	return AffinityScript.new()


## -- Scope: who can earn affinity at all --

func test_named_npc_ids_match_the_authored_layout_roster() -> void:
	# affinity.gd holds its own copy of the 4 named ids (it has no other reason to depend on map
	# layouts). Pin it against layout_common.gd's TOWN_NPCS/RANCH_NPCS — the actual source of
	# truth for who the authored NPCs are — so the copy can never silently drift out of sync.
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
	assert_eq(declared, authored,
		"NAMED_NPC_IDS is exactly TOWN_NPCS + RANCH_NPCS (the 4 authored NPCs)")


func test_is_named_npc_excludes_settlers_and_unknown_ids() -> void:
	assert_true(AffinityScript.is_named_npc(HARLAN))
	assert_true(AffinityScript.is_named_npc("rancher_silas"))
	assert_false(AffinityScript.is_named_npc("settler_1"),
		"procedurally-recruited settlers have no relationship track (Stage 1/2's scope decision)")
	assert_false(AffinityScript.is_named_npc("nobody"))
	assert_false(AffinityScript.is_named_npc(""))


## -- value_for / adjust / clamping --

func test_unknown_npc_starts_at_zero() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.value_for(HARLAN), 0, "a never-met NPC reads 0, with no entry created")
	assert_eq(affinity.value_for("nobody"), 0)
	affinity.free()


func test_adjust_accumulates_positive_and_negative_deltas() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 3)
	assert_eq(affinity.value_for(HARLAN), 3)
	affinity.adjust(HARLAN, 2)
	assert_eq(affinity.value_for(HARLAN), 5)
	affinity.adjust(HARLAN, -4)
	assert_eq(affinity.value_for(HARLAN), 1, "a disliked gift/neglect delta walks it back down")
	affinity.free()


func test_adjust_clamps_to_the_zero_ten_range() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 99)
	assert_eq(affinity.value_for(HARLAN), AffinityScript.MAX_AFFINITY, "clamped at the 10 ceiling")
	affinity.adjust(HARLAN, 5)
	assert_eq(affinity.value_for(HARLAN), 10, "already at the ceiling stays there")
	affinity.adjust(HARLAN, -99)
	assert_eq(affinity.value_for(HARLAN), AffinityScript.MIN_AFFINITY, "clamped at the 0 floor")
	affinity.adjust(HARLAN, -5)
	assert_eq(affinity.value_for(HARLAN), 0, "already at the floor stays there")
	affinity.free()


func test_adjust_tracks_each_npc_independently() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 4)
	affinity.adjust(MARTA, 7)
	assert_eq(affinity.value_for(HARLAN), 4)
	assert_eq(affinity.value_for(MARTA), 7, "per-NPC values never bleed into each other")
	affinity.free()


func test_affinity_changed_fires_only_on_a_real_change() -> void:
	var affinity := _make_affinity()
	var events: Array[Array] = []
	affinity.affinity_changed.connect(
		func(npc_id: String, value: int) -> void: events.append([npc_id, value]))
	affinity.adjust(HARLAN, 2)
	assert_eq(events, [[HARLAN, 2]], "a real change emits once with the new value")
	affinity.adjust(HARLAN, 99)
	assert_eq(events.size(), 2, "clamping to 10 is still a change from 2")
	assert_eq(events[1], [HARLAN, 10])
	affinity.adjust(HARLAN, 3)
	assert_eq(events.size(), 2, "a no-op push against the ceiling emits nothing")
	affinity.adjust(HARLAN, 0)
	assert_eq(events.size(), 2, "a zero delta emits nothing")
	affinity.free()


func test_a_noop_adjust_writes_nothing_at_all() -> void:
	# Not just "emits nothing": it must not create a 0 entry either, or every NPC the player ever
	# brushed past would be serialised into the save with a meaningless zero.
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 0)
	affinity.adjust(MARTA, -3)  # already at the 0 floor
	assert_eq(affinity.save_state()["values"], {},
		"no-op adjustments leave the saved value dict empty")
	affinity.free()


## -- Tier bucketing (the contract Stage 5 authors against) --

func test_tier_boundaries_are_exact() -> void:
	# Documented table (affinity.gd's class doc): 0-1 stranger, 2-4 acquaintance, 5-7 friend,
	# 8-10 close. Every boundary value is pinned here, both sides.
	assert_eq(AffinityScript.tier_for_value(0), AffinityScript.TIER_STRANGER)
	assert_eq(AffinityScript.tier_for_value(1), AffinityScript.TIER_STRANGER, "1 is still stranger")
	assert_eq(AffinityScript.tier_for_value(2), AffinityScript.TIER_ACQUAINTANCE,
		"2 is the first acquaintance value")
	assert_eq(AffinityScript.tier_for_value(4), AffinityScript.TIER_ACQUAINTANCE)
	assert_eq(AffinityScript.tier_for_value(5), AffinityScript.TIER_FRIEND,
		"5 is the first friend value — the tier Stage 5 gates its warmer content on")
	assert_eq(AffinityScript.tier_for_value(7), AffinityScript.TIER_FRIEND)
	assert_eq(AffinityScript.tier_for_value(8), AffinityScript.TIER_CLOSE, "8 is the first close value")
	assert_eq(AffinityScript.tier_for_value(10), AffinityScript.TIER_CLOSE)


func test_tier_for_value_clamps_out_of_range_input() -> void:
	assert_eq(AffinityScript.tier_for_value(-5), AffinityScript.TIER_STRANGER)
	assert_eq(AffinityScript.tier_for_value(999), AffinityScript.TIER_CLOSE)


func test_tier_for_reads_the_live_value() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.tier_for(MARTA), AffinityScript.TIER_STRANGER, "never met -> stranger")
	affinity.adjust(MARTA, 5)
	assert_eq(affinity.tier_for(MARTA), AffinityScript.TIER_FRIEND)
	affinity.adjust(MARTA, 5)
	assert_eq(affinity.tier_for(MARTA), AffinityScript.TIER_CLOSE)
	affinity.free()


## -- The talk tick (once per day, per NPC, named NPCs only) --

func test_talk_awards_once_then_refuses_the_same_day() -> void:
	var affinity := _make_affinity()
	assert_true(affinity.try_award_talk(HARLAN, 3), "the first conversation of day 3 awards")
	assert_eq(affinity.value_for(HARLAN), AffinityScript.TALK_AFFINITY_DELTA)
	assert_false(affinity.try_award_talk(HARLAN, 3),
		"re-opening the same conversation on day 3 awards nothing (no repeat-talk farming)")
	assert_false(affinity.try_award_talk(HARLAN, 3))
	assert_eq(affinity.value_for(HARLAN), AffinityScript.TALK_AFFINITY_DELTA,
		"the value is unchanged after the refused repeats")
	affinity.free()


func test_talk_awards_again_the_next_day() -> void:
	var affinity := _make_affinity()
	assert_true(affinity.try_award_talk(HARLAN, 3))
	assert_true(affinity.try_award_talk(HARLAN, 4), "a new day resets the cap")
	assert_eq(affinity.value_for(HARLAN), 2 * AffinityScript.TALK_AFFINITY_DELTA)
	affinity.free()


func test_talk_cap_is_per_npc_not_global() -> void:
	var affinity := _make_affinity()
	assert_true(affinity.try_award_talk(HARLAN, 5))
	assert_true(affinity.try_award_talk(MARTA, 5),
		"talking to Harlan today must not consume Marta's daily tick")
	assert_eq(affinity.value_for(HARLAN), AffinityScript.TALK_AFFINITY_DELTA)
	assert_eq(affinity.value_for(MARTA), AffinityScript.TALK_AFFINITY_DELTA)
	affinity.free()


func test_talk_never_awards_a_settler_or_unknown_npc() -> void:
	var affinity := _make_affinity()
	assert_false(affinity.try_award_talk("settler_1", 2), "settlers have no relationship track")
	assert_eq(affinity.value_for("settler_1"), 0)
	assert_eq(affinity.last_talked_day("settler_1"), -1,
		"a refused NPC accumulates no daily bookkeeping either")
	assert_false(affinity.try_award_talk("nobody", 2))
	affinity.free()


func test_talk_stops_awarding_at_the_ceiling() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, AffinityScript.MAX_AFFINITY)
	# try_award_talk still reports true (the daily tick WAS spent) but the clamped value holds —
	# talking at 10 is not an error, it just has nothing left to give.
	assert_true(affinity.try_award_talk(HARLAN, 6))
	assert_eq(affinity.value_for(HARLAN), AffinityScript.MAX_AFFINITY)
	affinity.free()


func test_last_talked_day_reports_never_as_minus_one() -> void:
	var affinity := _make_affinity()
	assert_eq(affinity.last_talked_day(HARLAN), -1, "never talked")
	affinity.try_award_talk(HARLAN, 9)
	assert_eq(affinity.last_talked_day(HARLAN), 9)
	affinity.free()


## -- Save/load round trip (scripts/save_data.gd's encode_affinity/decode_affinity) --

func test_encode_affinity_normalises_keys_and_int_values() -> void:
	# JSON round-trips ints as floats (see save_data.gd's class doc) — both dicts must come back
	# as ints, or `== day` comparisons in the talk cap would silently never match.
	var encoded := SaveData.encode_affinity({"marta": 4.0}, {"marta": 7.0})
	assert_eq(encoded, {"values": {"marta": 4}, "last_talked_day": {"marta": 7}})
	var decoded := SaveData.decode_affinity(encoded)
	assert_eq(decoded["values"]["marta"], 4)
	assert_eq(decoded["last_talked_day"]["marta"], 7)


func test_decode_affinity_defaults_empty_for_an_old_save() -> void:
	# Backward compatibility: a save written before this stage has no "affinity" key at all.
	var decoded := SaveData.decode_affinity({})
	assert_eq(decoded["values"], {})
	assert_eq(decoded["last_talked_day"], {})
	var partial := SaveData.decode_affinity({"values": {"marta": 2}})
	assert_eq(partial["values"], {"marta": 2})
	assert_eq(partial["last_talked_day"], {}, "a missing half defaults empty rather than erroring")


func test_save_state_matches_saveData_encode_affinity() -> void:
	var affinity := _make_affinity()
	affinity.try_award_talk(HARLAN, 4)
	affinity.adjust(MARTA, 6)
	var saved: Dictionary = affinity.save_state()
	assert_eq(saved, SaveData.encode_affinity(
		{HARLAN: 1, MARTA: 6}, {HARLAN: 4}))
	affinity.free()


func test_round_trip_through_json_preserves_values_and_the_daily_cap() -> void:
	var affinity := _make_affinity()
	affinity.try_award_talk(HARLAN, 4)
	affinity.try_award_talk(MARTA, 4)
	affinity.adjust(MARTA, 5)
	# Through real JSON text, not just the dicts — this is the path a save file actually takes.
	var text := JSON.stringify(affinity.save_state())
	var restored := _make_affinity()
	restored.load_state(JSON.parse_string(text))
	assert_eq(restored.value_for(HARLAN), 1)
	assert_eq(restored.value_for(MARTA), 6)
	assert_eq(restored.last_talked_day(HARLAN), 4)
	assert_false(restored.try_award_talk(HARLAN, 4),
		"the daily cap survives the reload — no second same-day tick after loading")
	assert_true(restored.try_award_talk(HARLAN, 5), "and still opens up the next day")
	affinity.free()
	restored.free()


func test_load_state_with_empty_data_leaves_a_fresh_track() -> void:
	var affinity := _make_affinity()
	affinity.adjust(HARLAN, 5)
	affinity.load_state({})
	assert_eq(affinity.value_for(HARLAN), 0,
		"an old save with no 'affinity' key loads a clean slate, never an error")
	assert_eq(affinity.last_talked_day(HARLAN), -1)
	affinity.free()


func test_load_state_reclamps_an_out_of_range_stored_value() -> void:
	# save_data.gd is the pure serialisation layer and knows nothing about the 0-10 range, so the
	# invariant is re-established here (affinity.gd's load_state).
	var affinity := _make_affinity()
	affinity.load_state(SaveData.encode_affinity({HARLAN: 99, MARTA: -4}, {}))
	assert_eq(affinity.value_for(HARLAN), AffinityScript.MAX_AFFINITY)
	assert_eq(affinity.value_for(MARTA), AffinityScript.MIN_AFFINITY)
	assert_eq(affinity.tier_for(HARLAN), AffinityScript.TIER_CLOSE)
	affinity.free()
