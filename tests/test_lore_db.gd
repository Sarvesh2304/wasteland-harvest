extends "res://tests/test_case.gd"
## scripts/lore_db.gd + data/lore_notes.json: unique ids, text that fits the reader, six notes per
## district, and next_unread's order and depth gating.

const LoreDB := preload("res://scripts/lore_db.gd")


func test_notes_are_well_formed() -> void:
	var ids := {}
	var per_depth := {}
	for n in LoreDB.notes():
		var id := String(n["id"])
		assert_false(ids.has(id), "unique id %s" % id)
		ids[id] = true
		assert_true(String(n["title"]).length() <= LoreDB.MAX_TITLE, "%s title fits" % id)
		assert_true(String(n["text"]).length() <= LoreDB.MAX_TEXT, "%s text fits" % id)
		assert_true(String(n["text"]).length() >= 60, "%s says something" % id)
		var d := int(n["min_depth"])
		per_depth[d] = int(per_depth.get(d, 0)) + 1
	assert_eq(LoreDB.notes().size(), 18)
	for d in [1, 2, 3]:
		assert_eq(int(per_depth.get(d, 0)), 6, "six notes for district %d" % d)


func test_next_unread_order_and_gating() -> void:
	var first := LoreDB.next_unread([], 1)
	assert_eq(String(first["id"]), String(LoreDB.notes()[0]["id"]), "file order")
	var read: Array = []
	for n in LoreDB.notes():
		if int(n["min_depth"]) == 1:
			read.append(String(n["id"]))
	assert_eq(LoreDB.next_unread(read, 1), {}, "depth-1 notes exhausted at depth 1")
	var deeper := LoreDB.next_unread(read, 2)
	assert_eq(int(deeper["min_depth"]), 2, "going deeper unlocks downtown notes")
	assert_eq(LoreDB.note("kaels_mark")["min_depth"], 3)
	assert_eq(LoreDB.note("nope"), {})
