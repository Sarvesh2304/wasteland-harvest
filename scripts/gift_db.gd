extends RefCounted
## Gift preferences (data/gifts.json, Milestone B 2026-10-08 — docs/SOCIAL_AND_QUESTS.md §4).
## Static module like item_db.gd: lazy JSON load, pure queries. An NPC's own lists win, then the
## universal lists, else the gift is "neutral". The *_in() variants take the data explicitly so
## the rules are testable without the file.

const PATH := "res://data/gifts.json"
const ItemDB := preload("res://scripts/item_db.gd")

const REACTIONS: Array[String] = ["loved", "liked", "neutral", "disliked", "hated"]
## Lists checked in this order (neutral has no list: it's the fallback).
const LISTS: Array[String] = ["loved", "liked", "disliked", "hated"]
## Types the player can hand over. Seeds, tools, weapons, ammo, placeables, equipment and quest
## items are never offered (holding them while you talk just talks).
const GIFTABLE_TYPES: Array[String] = ["crop", "food", "forage", "medicine", "resource"]
const NOT_GIFTABLE: Array[String] = ["fertilizer", "quality_fertilizer"]

static var _data: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) \
		if FileAccess.file_exists(PATH) else null
	_data = parsed if parsed is Dictionary else {}


static func data() -> Dictionary:
	_ensure_loaded()
	return _data


static func is_giftable(item_id: String) -> bool:
	if item_id == "" or NOT_GIFTABLE.has(item_id) or not ItemDB.has_item(item_id):
		return false
	return GIFTABLE_TYPES.has(ItemDB.item_type(item_id))


## How `npc_id` feels about `item_id`: one of REACTIONS.
static func reaction(npc_id: String, item_id: String) -> String:
	return reaction_in(data(), npc_id, item_id)


static func reaction_in(gifts: Dictionary, npc_id: String, item_id: String) -> String:
	var own: Dictionary = (gifts.get("npcs", {}) as Dictionary).get(npc_id, {})
	for list in LISTS:
		if (own.get(list, []) as Array).has(item_id):
			return list
	var universal: Dictionary = gifts.get("universal", {})
	for list in LISTS:
		if (universal.get(list, []) as Array).has(item_id):
			return list
	return "neutral"


## The NPC's own authored lists ({loved: [...], ...}); {} if none.
static func preferences(npc_id: String) -> Dictionary:
	return (data().get("npcs", {}) as Dictionary).get(npc_id, {})


static func reload_from_disk() -> void:
	_loaded = false
	_data = {}
	_ensure_loaded()
