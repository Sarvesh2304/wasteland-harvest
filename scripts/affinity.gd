extends Node
## Per-NPC friendship (Phase 7 Stage 3, reworked for Milestone B 2026-10-08 — see
## docs/SOCIAL_AND_QUESTS.md §2). One instance lives directly under Main, settlement-wide, like
## settlers.gd and animals.gd. It ticks nothing: friendship only moves because the player did
## something (talked, gave a gift, finished a request).
##
## ## Points and hearts
## Friendship is stored as POINTS, 0-2500, 250 to a heart (Stardew's scale): a day's first chat is
## +20, a loved gift +80, a finished request +150. value_for() reports whole HEARTS (0-10), and
## the dialogue tiers bucket hearts, so everything that reads value_for/tier_for is unchanged by
## the switch. (The first version stored hearts directly and gave a whole heart per chat, which
## maxed an NPC out in ten days of small talk.) No decay: the cozy contract (GDD §4).
##
## ## Gifts
## One gift per NPC per day, two per NPC per week (Mon-Sun; day 1 is a Monday), and a birthday
## gift ignores the weekly two and counts five times. The reaction comes from scripts/gift_db.gd.
## What an NPC thought of an item is remembered once it's been given (the PEOPLE tab shows it).
##
## ## Once-only lines
## Dialogue lines marked "once" are recorded in seen_lines after they play (dialogue_ui.gd), so
## they never repeat; that memory is saved with the rest of this section.
##
## ## Who earns friendship
## Only the named NPCs (NAMED_NPC_IDS, pinned against layout_common.gd's TOWN_NPCS + RANCH_NPCS by
## tests/test_affinity.gd). Settlers are interchangeable by design and have no track. The gate is
## in the award paths (talk, gift); adjust()/adjust_points() stay raw so a story beat can move any
## number deliberately.

## Emitted whenever an NPC's points actually change, with the new HEART count (an emission is
## always a real change; a no-op clamp at either end emits nothing).
signal affinity_changed(npc_id: String, value: int)
## A gift was given (dialogue_ui reacts with a line; the HUD floats the hearts).
signal gift_given(npc_id: String, item_id: String, reaction: String, points: int)

const SaveData := preload("res://scripts/save_data.gd")
const GiftDB := preload("res://scripts/gift_db.gd")

const POINTS_PER_HEART := SaveData.POINTS_PER_HEART
const MIN_AFFINITY := 0
const MAX_AFFINITY := 10
const MAX_POINTS := MAX_AFFINITY * POINTS_PER_HEART

## A day's first real conversation.
const TALK_POINTS := 20
## Finishing that NPC's notice-board request (scripts/quests.gd).
const REQUEST_POINTS := 150
## Per reaction (GiftDB's names).
const GIFT_POINTS := {"loved": 80, "liked": 45, "neutral": 20, "disliked": -20, "hated": -40}
const BIRTHDAY_MULTIPLIER := 5
const GIFTS_PER_WEEK := 2
const DAYS_PER_WEEK := 7

## The authored, named NPCs (Milestone B added Brask, Wren and Doc Ama).
const NAMED_NPC_IDS: Array[String] = [
	"mayor_harlan",
	"marta",
	"scout_kael",
	"rancher_silas",
	"brask",
	"wren",
	"doc_ama",
]

## Tiers by hearts (inclusive lower bounds): 0-1 stranger, 2-4 acquaintance, 5-7 friend, 8-10
## close. Dialogue gates on these names, never on raw numbers.
const TIER_STRANGER := "stranger"
const TIER_ACQUAINTANCE := "acquaintance"
const TIER_FRIEND := "friend"
const TIER_CLOSE := "close"
const TIERS: Array[String] = [TIER_STRANGER, TIER_ACQUAINTANCE, TIER_FRIEND, TIER_CLOSE]

const TIER_ACQUAINTANCE_MIN := 2
const TIER_FRIEND_MIN := 5
const TIER_CLOSE_MIN := 8

var _points: Dictionary = {}
var _last_talked_day: Dictionary = {}
var _last_gift_day: Dictionary = {}
## npc -> [week index, gifts given that week]
var _gift_week: Dictionary = {}
## npc -> {item_id: reaction}
var _known_gifts: Dictionary = {}
var _seen_lines: Dictionary = {}


## -- Pure helpers --

static func is_named_npc(npc_id: String) -> bool:
	return npc_id in NAMED_NPC_IDS


## The tier for a heart count (clamped, so total over every int).
static func tier_for_value(value: int) -> String:
	var clamped := clampi(value, MIN_AFFINITY, MAX_AFFINITY)
	if clamped >= TIER_CLOSE_MIN:
		return TIER_CLOSE
	if clamped >= TIER_FRIEND_MIN:
		return TIER_FRIEND
	if clamped >= TIER_ACQUAINTANCE_MIN:
		return TIER_ACQUAINTANCE
	return TIER_STRANGER


## 0 stranger .. 3 close; -1 for an unknown name.
static func tier_rank(tier: String) -> int:
	return TIERS.find(tier)


static func hearts_for_points(points: int) -> int:
	return clampi(points, 0, MAX_POINTS) / POINTS_PER_HEART


## Mon-Sun weeks, day 1 being a Monday (calendar.gd).
static func week_of(day: int) -> int:
	return (maxi(day, 1) - 1) / DAYS_PER_WEEK


## Points a gift is worth: the reaction's value, x5 on a birthday.
static func gift_points(reaction: String, birthday: bool) -> int:
	var base := int(GIFT_POINTS.get(reaction, GIFT_POINTS["neutral"]))
	return base * (BIRTHDAY_MULTIPLIER if birthday else 1)


## -- Live state --

## Whole hearts, 0-10.
func value_for(npc_id: String) -> int:
	return hearts_for_points(points_for(npc_id))


func points_for(npc_id: String) -> int:
	return int(_points.get(npc_id, 0))


func tier_for(npc_id: String) -> String:
	return tier_for_value(value_for(npc_id))


## Moves an NPC by whole HEARTS (kept for story beats and tests written against hearts).
func adjust(npc_id: String, delta: int) -> void:
	adjust_points(npc_id, delta * POINTS_PER_HEART)


## Moves an NPC by points, clamped to 0-2500. A no-op writes nothing and emits nothing.
func adjust_points(npc_id: String, delta: int) -> void:
	var before := points_for(npc_id)
	var after := clampi(before + delta, 0, MAX_POINTS)
	if after == before:
		return
	_points[npc_id] = after
	affinity_changed.emit(npc_id, hearts_for_points(after))


func last_talked_day(npc_id: String) -> int:
	return int(_last_talked_day.get(npc_id, -1))


## The day's first real conversation (dialogue_ui.gd): +TALK_POINTS once per NPC per day, named
## NPCs only. True when points were actually granted.
func try_award_talk(npc_id: String, day: int) -> bool:
	if not is_named_npc(npc_id):
		return false
	if last_talked_day(npc_id) == day:
		return false
	_last_talked_day[npc_id] = day
	adjust_points(npc_id, TALK_POINTS)
	return true


func talked_today(npc_id: String, day: int) -> bool:
	return last_talked_day(npc_id) == day


## -- Gifts --

func gifted_today(npc_id: String, day: int) -> bool:
	return int(_last_gift_day.get(npc_id, -1)) == day


func gifts_this_week(npc_id: String, day: int) -> int:
	var entry: Array = _gift_week.get(npc_id, [-1, 0])
	return int(entry[1]) if int(entry[0]) == week_of(day) else 0


## Why a gift can't be given right now: "" (it can), "not_named", "not_giftable", "today" (one
## already given today) or "week" (two already this week, and it isn't their birthday).
func gift_refusal(npc_id: String, item_id: String, day: int, birthday: bool) -> String:
	if not is_named_npc(npc_id):
		return "not_named"
	if not GiftDB.is_giftable(item_id):
		return "not_giftable"
	if gifted_today(npc_id, day):
		return "today"
	if not birthday and gifts_this_week(npc_id, day) >= GIFTS_PER_WEEK:
		return "week"
	return ""


## Gives `item_id` to `npc_id` (the caller has already checked gift_refusal and takes the item out
## of the inventory). Returns {"reaction", "points"}. A birthday gift doesn't use up one of the
## week's two.
func give_gift(npc_id: String, item_id: String, day: int, birthday: bool) -> Dictionary:
	var reaction := GiftDB.reaction(npc_id, item_id)
	var points := gift_points(reaction, birthday)
	_last_gift_day[npc_id] = day
	if not birthday:
		_gift_week[npc_id] = [week_of(day), gifts_this_week(npc_id, day) + 1]
	var tastes: Dictionary = _known_gifts.get(npc_id, {})
	tastes[item_id] = reaction
	_known_gifts[npc_id] = tastes
	adjust_points(npc_id, points)
	gift_given.emit(npc_id, item_id, reaction, points)
	return {"reaction": reaction, "points": points}


## {item_id: reaction} the player has discovered for `npc_id`.
func known_gifts(npc_id: String) -> Dictionary:
	return _known_gifts.get(npc_id, {})


## -- Once-only dialogue lines --

func has_seen_line(line_id: String) -> bool:
	return _seen_lines.has(line_id)


func mark_line_seen(line_id: String) -> void:
	if line_id != "":
		_seen_lines[line_id] = true


## -- Save/load (scripts/save_data.gd's encode_affinity/decode_affinity) --

func save_state() -> Dictionary:
	var seen: Array = _seen_lines.keys()
	seen.sort()
	return SaveData.encode_affinity(_points, _last_talked_day, {
		"last_gift_day": _last_gift_day, "gift_week": _gift_week,
		"known_gifts": _known_gifts, "seen_lines": seen})


## Restores everything from the "affinity" save section. An old save without the section (or
## from before points) decodes to a valid state; points are re-clamped on the way in.
func load_state(data: Dictionary) -> void:
	var decoded := SaveData.decode_affinity(data)
	_points = {}
	for npc_id in decoded["points"]:
		var value := clampi(int(decoded["points"][npc_id]), 0, MAX_POINTS)
		if value > 0:
			_points[npc_id] = value
	_last_talked_day = decoded["last_talked_day"]
	_last_gift_day = decoded["last_gift_day"]
	_gift_week = decoded["gift_week"]
	_known_gifts = decoded["known_gifts"]
	_seen_lines = {}
	for line_id in decoded["seen_lines"]:
		_seen_lines[String(line_id)] = true
