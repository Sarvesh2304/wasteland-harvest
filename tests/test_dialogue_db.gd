extends "res://tests/test_case.gd"
## Phase 5 Stage 1 dialogue data + traversal (scripts/dialogue_db.gd / data/dialogue.json).
## Covers the loader accessors and the pure advance_from()/visible_chars() rules dialogue_ui.gd
## drives — same "pure core, headless-testable" split as tests/test_npc_grid.gd.

const DialogueDB := preload("res://scripts/dialogue_db.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const ROSTER_IDS := ["mayor_harlan", "marta", "scout_kael", "brask", "wren", "doc_ama"]

## Phase 7 Stage 1: the 4 authored, named NPCs (the 3 town-core roster ids plus the Ranch keeper)
## — the only NPCs that carry a personality tag. Settlers are deliberately excluded (they're
## registered in memory via DialogueDB.register_runtime and are interchangeable by design).
const NAMED_NPC_IDS := ["mayor_harlan", "marta", "scout_kael", "rancher_silas", "brask", "wren", "doc_ama"]

## The 6 frozen archetypes from the original roadmap HTML — the exact, complete valid set.
const VALID_PERSONALITIES := [
	"Paranoid Survivor",
	"Optimistic Builder",
	"Gruff Soldier",
	"Gentle Medic",
	"Secretive Scavenger",
	"Pragmatic Trader",
]

## The authored assignment itself, pinned so a later content edit can't silently re-tag an NPC.
const EXPECTED_PERSONALITIES := {
	"mayor_harlan": "Optimistic Builder",
	"marta": "Pragmatic Trader",
	"scout_kael": "Paranoid Survivor",
	"rancher_silas": "Gentle Medic",
	"brask": "Gruff Soldier",
	"wren": "Secretive Scavenger",
	"doc_ama": "Gentle Medic",
}


func test_all_town_core_npcs_have_dialogue_entries() -> void:
	# Every id in the shared town-core roster (layout_common.gd's TOWN_NPCS, the same data all 3
	# starting layouts' npcs() delegate to) must resolve to a real data/dialogue.json entry —
	# otherwise dialogue_ui.open_dialogue() would silently no-op for that NPC in-game.
	for entry in LayoutCommon.TOWN_NPCS:
		var id := String(entry["id"])
		assert_true(DialogueDB.has_dialogue(id), "roster npc '%s' has a dialogue.json entry" % id)


func test_roster_ids_match_expected_town_npcs() -> void:
	var ids: Array[String] = []
	for entry in LayoutCommon.TOWN_NPCS:
		ids.append(String(entry["id"]))
	for expected in ROSTER_IDS:
		assert_true(expected in ids, "roster includes '%s'" % expected)
	assert_eq(ids.size(), 6, "6 town NPCs (Milestone B added Brask, Wren and Doc Ama)")


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


## -- Phase 7 Stage 1: personality tags --

func test_personality_resolves_for_every_named_npc() -> void:
	for id in NAMED_NPC_IDS:
		assert_eq(DialogueDB.personality(id), EXPECTED_PERSONALITIES[id],
			"%s's authored personality tag" % id)


func test_every_named_npc_personality_is_from_the_valid_set() -> void:
	# Well-formedness: a typo'd or invented archetype string would silently break every later
	# stage that keys tone/flavor off this field, so pin it to the frozen 6.
	for id in NAMED_NPC_IDS:
		var tag := DialogueDB.personality(id)
		assert_ne(tag, "", "%s has a personality tag at all" % id)
		assert_true(tag in VALID_PERSONALITIES,
			"%s's personality '%s' is one of the 6 frozen archetypes" % [id, tag])


func test_no_other_npc_id_has_a_personality() -> void:
	# Scope guard: personality tags are exclusively for the 4 named NPCs this stage. Checked
	# against the live cache (so a runtime-registered settler tree would be caught too) AND
	# against the raw file, which must contain exactly those 4 authored entries and nothing else.
	for id in DialogueDB.all_npc_ids():
		if id in NAMED_NPC_IDS:
			continue
		assert_eq(DialogueDB.personality(id), "",
			"non-named npc '%s' must not carry a personality tag" % id)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DialogueDB.PATH))
	assert_true(parsed is Dictionary, "data/dialogue.json parses as a dictionary")
	var authored: Dictionary = parsed
	authored.erase("_comment")
	assert_eq(authored.size(), NAMED_NPC_IDS.size(),
		"data/dialogue.json holds only the 4 named NPCs (settlers are runtime-registered)")
	for key in authored.keys():
		assert_true(String(key) in NAMED_NPC_IDS,
			"authored dialogue entry '%s' is one of the 4 named NPCs" % String(key))


func test_personality_unknown_id_returns_empty() -> void:
	# Same unknown-id contract as display_name()/start_node_id().
	assert_eq(DialogueDB.personality("nobody"), "", "unknown npc id yields no personality")
	assert_eq(DialogueDB.personality(""), "", "empty npc id yields no personality")


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


## -- Phase 7 Stage 3: affinity-gated choices (choice_available's pure logic) --

func test_choice_without_min_affinity_is_always_available() -> void:
	# Backward compatibility is the whole point: no choice in data/dialogue.json carries the field
	# yet, so an untagged choice must show at every value, including 0.
	var choice := {"text": "Sure.", "next": "yes"}
	assert_true(DialogueDB.choice_available(choice, 0))
	assert_true(DialogueDB.choice_available(choice, 10))


func test_choice_min_affinity_threshold_is_inclusive() -> void:
	var choice := {"text": "Can I ask you something personal?", "next": "secret", "min_affinity": 5}
	assert_false(DialogueDB.choice_available(choice, 4), "one below the threshold stays hidden")
	assert_true(DialogueDB.choice_available(choice, 5), "exactly at the threshold appears")
	assert_true(DialogueDB.choice_available(choice, 9))


func test_choice_min_affinity_zero_behaves_like_no_gate() -> void:
	var choice := {"text": "Hello.", "next": "hi", "min_affinity": 0}
	assert_true(DialogueDB.choice_available(choice, 0))


func test_every_authored_choice_is_ungated_this_stage() -> void:
	# Stage 3 ships the MECHANISM only — the first gated line is Stage 5's job. If this ever fails,
	# gated content landed without the ROADMAP writeup that goes with it.
	for id in NAMED_NPC_IDS:
		var nodes: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(DialogueDB.PATH))[id].get("nodes", {})
		for node_id in nodes:
			for choice in DialogueDB.node_choices(nodes[node_id]):
				assert_false((choice as Dictionary).has("min_affinity"),
					"%s.%s carries no min_affinity yet (Stage 5 authors the first)" % [id, node_id])


func test_visible_chars_progresses_from_zero_to_full() -> void:
	assert_eq(DialogueDB.visible_chars(20, 0.0, 10.0), 0, "nothing revealed at t=0")
	assert_eq(DialogueDB.visible_chars(20, 0.5, 10.0), 5, "5 chars after 0.5s at 10 chars/sec")
	assert_eq(DialogueDB.visible_chars(20, 5.0, 10.0), 20, "clamps at the full text length")


func test_visible_chars_never_negative_or_over_total() -> void:
	assert_eq(DialogueDB.visible_chars(10, -1.0, 10.0), 0, "negative elapsed clamps to 0")
	assert_eq(DialogueDB.visible_chars(0, 5.0, 10.0), 0, "empty text has nothing to reveal")
