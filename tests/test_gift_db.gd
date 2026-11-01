extends "res://tests/test_case.gd"
## scripts/gift_db.gd (Milestone B): what can be given, and how an NPC's own tastes override the
## universal ones (on inline data), plus sanity checks on the authored data/gifts.json.

const GiftDB := preload("res://scripts/gift_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")

const DATA := {
	"universal": {"loved": ["prewar_relic"], "liked": ["cooked_meal"], "hated": ["rotgut"]},
	"npcs": {
		"doc_ama": {"loved": ["cleanleaf_kale"], "liked": ["prewar_relic"], "disliked": ["cooked_meal"]},
	},
}


func test_giftable_types() -> void:
	assert_true(GiftDB.is_giftable("glow_melon"), "crops")
	assert_true(GiftDB.is_giftable("cooked_meal"), "food")
	assert_true(GiftDB.is_giftable("glowcap"), "forage")
	assert_true(GiftDB.is_giftable("bandage"), "medicine")
	assert_true(GiftDB.is_giftable("copper_wire"), "resources")
	assert_false(GiftDB.is_giftable("seed_rain_radish"), "never seeds: holding them while you talk just talks")
	assert_false(GiftDB.is_giftable("hoe"))
	assert_false(GiftDB.is_giftable("machete"))
	assert_false(GiftDB.is_giftable("pistol_ammo"))
	assert_false(GiftDB.is_giftable("crate_chest"))
	assert_false(GiftDB.is_giftable("hazmat_mask"))
	assert_false(GiftDB.is_giftable("lore_note"))
	assert_false(GiftDB.is_giftable("fertilizer"))
	assert_false(GiftDB.is_giftable(""))
	assert_false(GiftDB.is_giftable("no_such_item"))


func test_own_tastes_override_universal() -> void:
	assert_eq(GiftDB.reaction_in(DATA, "doc_ama", "cleanleaf_kale"), "loved")
	assert_eq(GiftDB.reaction_in(DATA, "doc_ama", "prewar_relic"), "liked", "her list beats the universal love")
	assert_eq(GiftDB.reaction_in(DATA, "doc_ama", "cooked_meal"), "disliked")
	assert_eq(GiftDB.reaction_in(DATA, "doc_ama", "rotgut"), "hated", "falls back to universal")
	assert_eq(GiftDB.reaction_in(DATA, "marta", "prewar_relic"), "loved")
	assert_eq(GiftDB.reaction_in(DATA, "marta", "stone"), "neutral")
	assert_eq(GiftDB.reaction_in({}, "marta", "stone"), "neutral", "no data, no opinions")


func test_authored_gifts_are_real_giftable_and_unambiguous() -> void:
	var data := GiftDB.data()
	if data.is_empty():
		fail("data/gifts.json is missing or empty")
		return
	var lists: Array = [data.get("universal", {})]
	for npc_id in (data.get("npcs", {}) as Dictionary):
		assert_true(AffinityScript.is_named_npc(String(npc_id)), "%s is a named NPC" % npc_id)
		lists.append(data["npcs"][npc_id])
	for prefs in lists:
		var seen := {}
		for list in GiftDB.LISTS:
			for item in (prefs as Dictionary).get(list, []):
				assert_true(ItemDB.has_item(String(item)), "%s exists" % item)
				assert_true(GiftDB.is_giftable(String(item)), "%s is giftable" % item)
				assert_false(seen.has(item), "%s appears in one list only" % item)
				seen[item] = true


func test_every_named_npc_has_tastes() -> void:
	for npc_id in AffinityScript.NAMED_NPC_IDS:
		var prefs := GiftDB.preferences(npc_id)
		assert_true((prefs.get("loved", []) as Array).size() >= 3, "%s loves 3+ things" % npc_id)
		assert_true((prefs.get("liked", []) as Array).size() >= 5, "%s likes 5+ things" % npc_id)
		assert_true((prefs.get("disliked", []) as Array).size() >= 2, "%s dislikes 2+ things" % npc_id)
		assert_true((prefs.get("hated", []) as Array).size() >= 1, "%s hates something" % npc_id)
