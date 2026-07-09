extends "res://tests/test_case.gd"
## Phase 5 Stage 1 dialogue data + traversal (scripts/dialogue_db.gd / data/dialogue.json).
## Covers the loader accessors and the pure advance_from()/visible_chars() rules dialogue_ui.gd
## drives — same "pure core, headless-testable" split as tests/test_npc_grid.gd.

const DialogueDB := preload("res://scripts/dialogue_db.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const ROSTER_IDS := ["mayor_harlan", "marta", "scout_kael"]


func test_all_town_core_npcs_have_dialogue_entries() -> void:
	# Every id in the shared town-core roster (layout_common.gd's TOWN_NPCS, the same data all 3
	# starting layouts' npcs() delegate to) must resolve to a real data/dialogue.json entry —
	# otherwise dialogue_ui.open_dialogue() would silently no-op for that NPC in-game.
	for entry in LayoutCommon.TOWN_NPCS:
		var id := String(entry["id"])
		assert_true(DialogueDB.has_dialogue(id), "roster npc '%s' has a dialogue.json entry" % id)


func test_roster_ids_match_expected_three_npcs() -> void:
	var ids: Array[String] = []
	for entry in LayoutCommon.TOWN_NPCS:
		ids.append(String(entry["id"]))
	for expected in ROSTER_IDS:
		assert_true(expected in ids, "roster includes '%s'" % expected)
	assert_eq(ids.size(), 3, "exactly 3 town-core NPCs this stage")


func test_display_name_and_start_node_resolve_for_every_npc() -> void:
	for id in ROSTER_IDS:
		assert_ne(DialogueDB.display_name(id), "", "%s has a display name" % id)
		var start_id := DialogueDB.start_node_id(id)
		assert_ne(start_id, "", "%s has a start node id" % id)
		var node := DialogueDB.dialogue_node(id, start_id)
		assert_false(node.is_empty(), "%s's start node resolves to real node data" % id)
		assert_ne(String(node.get("text", "")), "", "%s's start node has text" % id)


func test_unknown_npc_or_node_returns_empty() -> void:
	assert_false(DialogueDB.has_dialogue("nobody"))
	assert_eq(DialogueDB.display_name("nobody"), "")
	assert_true(DialogueDB.dialogue_node("mayor_harlan", "not_a_real_node").is_empty())


func test_advance_from_linear_node_follows_next() -> void:
	var node := {"text": "hi", "next": "second"}
	assert_eq(DialogueDB.advance_from(node, 0), "second")


func test_advance_from_terminal_node_returns_empty_string() -> void:
	var node := {"text": "the end"}
	assert_eq(DialogueDB.advance_from(node, 0), "",
		"a node with neither next nor choices signals close")


func test_advance_from_choice_node_follows_selected_index() -> void:
	var node := {
		"text": "pick one",
		"choices": [{"text": "a", "next": "node_a"}, {"text": "b", "next": "node_b"}],
	}
	assert_eq(DialogueDB.advance_from(node, 0), "node_a")
	assert_eq(DialogueDB.advance_from(node, 1), "node_b")


func test_advance_from_choice_clamps_out_of_range_index() -> void:
	# A stray/uninitialized choice_index must never dead-end a conversation.
	var node := {
		"text": "pick one",
		"choices": [{"text": "a", "next": "node_a"}, {"text": "b", "next": "node_b"}],
	}
	assert_eq(DialogueDB.advance_from(node, 99), "node_b", "clamps to the last choice")
	assert_eq(DialogueDB.advance_from(node, -5), "node_a", "clamps to the first choice")


func test_node_choices_empty_for_linear_and_terminal_nodes() -> void:
	assert_true(DialogueDB.node_choices({"text": "hi", "next": "x"}).is_empty())
	assert_true(DialogueDB.node_choices({"text": "hi"}).is_empty())


## Every roster NPC's actual data (not a synthetic fixture) exercises real "basic branching":
## at least one choice node whose two options lead to distinct next nodes.
func test_every_npc_has_at_least_one_real_branch() -> void:
	for id in ROSTER_IDS:
		var found_branch := false
		var start_id := DialogueDB.start_node_id(id)
		var visited := {}
		var queue: Array[String] = [start_id]
		while not queue.is_empty():
			var node_id: String = queue.pop_back()
			if visited.has(node_id) or node_id == "":
				continue
			visited[node_id] = true
			var node := DialogueDB.dialogue_node(id, node_id)
			var choices := DialogueDB.node_choices(node)
			if choices.size() >= 2:
				found_branch = true
				var targets := {}
				for choice in choices:
					targets[String(choice.get("next", ""))] = true
					queue.append(String(choice.get("next", "")))
				assert_true(targets.size() >= 2,
					"%s's branch choices lead to distinct next nodes" % id)
			else:
				queue.append(String(node.get("next", "")))
		assert_true(found_branch, "%s's dialogue tree has at least one 2+ option branch" % id)


func test_visible_chars_progresses_from_zero_to_full() -> void:
	assert_eq(DialogueDB.visible_chars(20, 0.0, 10.0), 0, "nothing revealed at t=0")
	assert_eq(DialogueDB.visible_chars(20, 0.5, 10.0), 5, "5 chars after 0.5s at 10 chars/sec")
	assert_eq(DialogueDB.visible_chars(20, 5.0, 10.0), 20, "clamps at the full text length")


func test_visible_chars_never_negative_or_over_total() -> void:
	assert_eq(DialogueDB.visible_chars(10, -1.0, 10.0), 0, "negative elapsed clamps to 0")
	assert_eq(DialogueDB.visible_chars(0, 5.0, 10.0), 0, "empty text has nothing to reveal")
