extends RefCounted
## Pure rules for one-time scripted dialogue beats.
##
## The beat content stays in data/dialogue.json; this module only names its trigger and supplies
## the day/seen guard so the day-start wiring in main.gd and its tests share one rule.

const DAY_28_FOOD_SHORTAGE_DAY := 28
const DAY_28_FOOD_SHORTAGE_NPC_ID := "mayor_harlan"
const DAY_28_FOOD_SHORTAGE_NODE_ID := "day_28_food_shortage"


static func should_trigger_day_28_food_shortage(day: int, already_seen: bool) -> bool:
	return day == DAY_28_FOOD_SHORTAGE_DAY and not already_seen
