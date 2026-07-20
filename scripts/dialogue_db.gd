extends RefCounted
## Loader + pure traversal logic for data/dialogue.json — Phase 5 Stage 1's NPC dialogue data
## (ROADMAP.md: "dialogue stored in JSON for easy editing"). Mirrors scripts/item_db.gd /
## scripts/building_db.gd exactly: static functions, JSON parsed once and cached, every consumer
## (scripts/dialogue_ui.gd, scripts/npc.gd's name plate, tests) goes through these accessors.
##
## ## Data shape (per npc id, matching map_layouts' npcs() ids)
##   {"name": String, "start": String, "nodes": {node_id: node}}
## where a node is one of:
##   {"text": String, "next": node_id}                       — linear beat, advance continues
##   {"text": String, "choices": [{"text", "next"}, ...]}    — branch point (2-3 options)
##   {"text": String}                                        — terminal, advance closes the box
## Traversal is advance_from() below — pure, headless-testable (tests/test_dialogue_db.gd), the
## same "rules as static functions on plain data" split farm_grid.gd documents.
##
## Scope note (ROADMAP Phase 5 Stage 1): "basic branching" means one choice point per NPC whose
## options lead to different terminal lines — deliberately not a deep tree, no conditions/flags/
## affinity gating (Phase 7) and no quest hooks (Phase 13). The shape above is forward-compatible
## with both (a node can grow fields without breaking advance_from).
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const DialogueDB := preload("res://scripts/dialogue_db.gd")`.

const PATH := "res://data/dialogue.json"

static var _dialogues: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	_dialogues = parsed if parsed is Dictionary else {}
	_dialogues.erase("_comment")


static func has_dialogue(npc_id: String) -> bool:
	_ensure_loaded()
	return _dialogues.has(npc_id)


static func all_npc_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for key in _dialogues.keys():
		out.append(String(key))
	return out


## The speaker name the dialogue box's plate shows.
static func display_name(npc_id: String) -> String:
	_ensure_loaded()
	return String(_dialogues.get(npc_id, {}).get("name", ""))


static func start_node_id(npc_id: String) -> String:
	_ensure_loaded()
	return String(_dialogues.get(npc_id, {}).get("start", ""))


## The node dictionary for (npc_id, node_id), or {} if either is unknown. Named dialogue_node
## (not get_node) to stay clear of engine-builtin name collisions on the preloaded script
## resource — the same reasoning as ItemDB.is_tool_item's naming (see its comment).
static func dialogue_node(npc_id: String, node_id: String) -> Dictionary:
	_ensure_loaded()
	var nodes: Dictionary = _dialogues.get(npc_id, {}).get("nodes", {})
	return nodes.get(node_id, {})


## -- Pure traversal / presentation math (headless-testable, no I/O) --

## The choices array of a node ([] for linear/terminal nodes).
static func node_choices(node: Dictionary) -> Array:
	var choices = node.get("choices", [])
	return choices if choices is Array else []


## Where advancing goes from a node: a choice node follows the selected option's "next" (the
## index is clamped into range, so a stray selection state can never dead-end a conversation),
## a linear node follows its own "next", and a terminal node returns "" (meaning: close).
static func advance_from(node: Dictionary, choice_index: int) -> String:
	var choices := node_choices(node)
	if not choices.is_empty():
		var choice: Dictionary = choices[clampi(choice_index, 0, choices.size() - 1)]
		return String(choice.get("next", ""))
	return String(node.get("next", ""))


## Character-by-character reveal (ROADMAP: "character-by-character text"): how many characters
## of a total-length text are visible after `elapsed` seconds at `chars_per_second`.
static func visible_chars(total: int, elapsed: float, chars_per_second: float) -> int:
	return clampi(int(elapsed * chars_per_second), 0, total)


## Test-only hook, same as ItemDB/BuildingDB.reload_from_disk.
static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()


## -- Runtime-only registration (Phase 8 Stage 3: settler arrivals) --
## An additive layer on top of the disk-loaded cache: a settler visitor/flavor tree doesn't exist
## as authored data/dialogue.json content, so scripts/settlers.gd registers/unregisters it here
## directly, in memory only — reload_from_disk()/a fresh boot wipes it like any other in-memory-
## only state in this codebase (npc.gd's own class doc notes NPC state itself isn't persisted
## either). `data` must already be the same node shape every other entry uses (see class doc).

## Merges `data` into the in-memory cache under `npc_id`, overwriting any existing runtime OR
## authored entry for that id (in memory only — never touches data/dialogue.json on disk).
static func register_runtime(npc_id: String, data: Dictionary) -> void:
	_ensure_loaded()
	_dialogues[npc_id] = data


## Removes a runtime-registered id from the in-memory cache. No-op if the id was never
## registered (or was already removed) — never errors on a stale double-call.
static func unregister_runtime(npc_id: String) -> void:
	_ensure_loaded()
	_dialogues.erase(npc_id)
