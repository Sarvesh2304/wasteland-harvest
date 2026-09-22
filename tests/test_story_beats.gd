extends "res://tests/test_case.gd"
## Day-28 scripted beat rules and authored dialogue (ROADMAP Phase 5).

const DialogueDB := preload("res://scripts/dialogue_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const StoryBeats := preload("res://scripts/story_beats.gd")


func _through_json(value):
	return JSON.parse_string(JSON.stringify(value))


func test_day_28_food_shortage_triggers_only_once_on_day_28() -> void:
	assert_false(StoryBeats.should_trigger_day_28_food_shortage(27, false),
		"the beat does not start before Day 28")
	assert_true(StoryBeats.should_trigger_day_28_food_shortage(28, false),
		"an unseen beat starts on Day 28")
	assert_false(StoryBeats.should_trigger_day_28_food_shortage(28, true),
		"the seen flag prevents a repeat")
	assert_false(StoryBeats.should_trigger_day_28_food_shortage(29, false),
		"the beat is not a recurring daily line")


func test_day_28_food_shortage_dialogue_is_harlan_reserve_and_farm_content() -> void:
	assert_true(DialogueDB.has_dialogue(StoryBeats.DAY_28_FOOD_SHORTAGE_NPC_ID))
	var first := DialogueDB.dialogue_node(StoryBeats.DAY_28_FOOD_SHORTAGE_NPC_ID,
		StoryBeats.DAY_28_FOOD_SHORTAGE_NODE_ID)
	assert_ne(String(first.get("text", "")), "")
	assert_true(String(first.get("text", "")).to_lower().contains("reserve"))
	var follow_up := DialogueDB.dialogue_node(StoryBeats.DAY_28_FOOD_SHORTAGE_NPC_ID,
		String(first.get("next", "")))
	assert_true(String(follow_up.get("text", "")).to_lower().contains("farm"))
	assert_true(String(follow_up.get("text", "")).to_lower().contains("counting"))


func test_day_28_food_shortage_seen_flag_round_trips_through_json() -> void:
	var encoded := SaveData.encode_story_flags(true)
	var decoded := SaveData.decode_story_flags(_through_json(encoded))
	assert_true(decoded["day_28_food_shortage_seen"],
		"the one-time beat state survives JSON save/load")
	assert_false(SaveData.decode_story_flags({})["day_28_food_shortage_seen"],
		"older saves default the additive flag to unseen")
