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
##   {"text": String, "choices": [{"text", "next", "min_affinity"?}, ...]}
##                                                           — branch point (2-3 options); a
##                                                             choice's OPTIONAL "min_affinity"
##                                                             int hides it below that
##                                                             relationship value (Phase 7
##                                                             Stage 3's choice_available below;
##                                                             absent = always shown)
##   {"text": String}                                        — terminal, advance closes the box
## Traversal is advance_from() below — pure, headless-testable (tests/test_dialogue_db.gd), the
## same "rules as static functions on plain data" split farm_grid.gd documents.
##
## Scope note (ROADMAP Phase 5 Stage 1): "basic branching" means one choice point per NPC whose
## options lead to different terminal lines — deliberately not a deep tree, and no quest hooks
## (Phase 13). The shape above is forward-compatible with those (a node can grow fields without
## breaking advance_from). Phase 7 Stage 3 added the first such field: a choice's optional
## "min_affinity" (choice_available below). The MECHANISM exists as of that stage; no authored
## line in data/dialogue.json uses it yet — Stage 5 writes the first gated content.
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


## Phase 7 Stage 1: the NPC's personality archetype tag, one of the 6 frozen roadmap strings
## (Paranoid Survivor, Optimistic Builder, Gruff Soldier, Gentle Medic, Secretive Scavenger,
## Pragmatic Trader). "" for an unknown id AND for any NPC without the field — only the 4 named
## NPCs are tagged; settlers (register_runtime below) are interchangeable by design and stay
## untagged. Pure data lookup: later stages (schedule flavor text, dialogue tone) read it, nothing
## in this file's traversal branches on it.
static func personality(npc_id: String) -> String:
	_ensure_loaded()
	return String(_dialogues.get(npc_id, {}).get("personality", ""))


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


## Phase 7 Stage 3: whether a choice is offered at the player's current affinity with this NPC.
## A choice may carry an optional `"min_affinity": int`; absent (every choice in
## data/dialogue.json today) means unconditional, so this is fully backward-compatible and every
## existing branch behaves exactly as it did before. The comparison is inclusive: a choice tagged
## min_affinity 5 appears at exactly 5.
##
## Pure and domain-agnostic on purpose — it takes the affinity VALUE as a plain int and knows
## nothing about scripts/affinity.gd, who the named NPCs are, or how tiers bucket. The actual
## filtering of a rendered choice list lives in scripts/dialogue_ui.gd, the same split the
## OPEN_STORE/OPEN_RANCH_STORE sentinels already established for keeping this file free of
## runtime/domain concerns (see class doc).
static func choice_available(choice: Dictionary, affinity: int) -> bool:
	if not choice.has("min_affinity"):
		return true
	return affinity >= int(choice.get("min_affinity", 0))


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


## -- v2: daily context lines, repeats, gift reactions, service nodes, birthdays (Milestone B
##    2026-10-08, docs/SOCIAL_AND_QUESTS.md §3). An entry without "lines" (a settler) keeps the
##    v1 behaviour: every conversation is its start tree. --

const TIME_BANDS: Array[String] = ["morning", "afternoon", "evening", "night"]
const WHEN_KEYS: Array[String] = ["season", "weather", "time", "weekday", "tier", "tier_max", "flag", "not_flag"]
## Mirrors scripts/affinity.gd's TIERS (kept here so this module stays free of node scripts).
const TIER_ORDER: Array[String] = ["stranger", "acquaintance", "friend", "close"]


static func entry(npc_id: String) -> Dictionary:
	_ensure_loaded()
	return _dialogues.get(npc_id, {})


## True when the NPC speaks v2 daily lines (named NPCs); settlers don't.
static func has_daily_lines(npc_id: String) -> bool:
	return not (entry(npc_id).get("lines", []) as Array).is_empty()


static func daily_lines(npc_id: String) -> Array:
	return entry(npc_id).get("lines", [])


static func repeat_lines(npc_id: String) -> Array:
	return entry(npc_id).get("repeat", [])


## Gift reaction lines of `kind` (loved/liked/neutral/disliked/hated/birthday/birthday_loved).
static func gift_lines(npc_id: String, kind: String) -> Array:
	return (entry(npc_id).get("gift", {}) as Dictionary).get(kind, [])


## {"season": String, "day": int}, or {} if none.
static func birthday(npc_id: String) -> Dictionary:
	var b = entry(npc_id).get("birthday", {})
	if b is Dictionary and b.has("season") and b.has("day"):
		return {"season": String(b["season"]), "day": int(b["day"])}
	return {}


static func service_node_id(npc_id: String) -> String:
	return String(entry(npc_id).get("service", ""))


static func service_when(npc_id: String) -> Dictionary:
	var w = entry(npc_id).get("service_when", {})
	return w if w is Dictionary else {}


## The time band for a clock reading (minutes past midnight, 0-1439): morning 6:00-11:59,
## afternoon 12:00-16:59, evening 17:00-20:59, night 21:00-5:59.
static func time_band(minutes: float) -> String:
	if minutes >= 21 * 60 or minutes < 6 * 60:
		return "night"
	if minutes >= 17 * 60:
		return "evening"
	if minutes >= 12 * 60:
		return "afternoon"
	return "morning"


## Whether every condition in `when` holds for `ctx` ({season, weather, time, weekday, tier,
## flags: {flag: true}}). An unknown key never matches, so a typo can't make a line play everywhere.
static func when_matches(when: Dictionary, ctx: Dictionary) -> bool:
	var flags: Dictionary = ctx.get("flags", {})
	for key in when:
		var want := String(when[key])
		match String(key):
			"season", "weather", "time", "weekday":
				if String(ctx.get(key, "")) != want:
					return false
			"tier":
				if TIER_ORDER.find(String(ctx.get("tier", "stranger"))) < TIER_ORDER.find(want):
					return false
			"tier_max":
				if TIER_ORDER.find(String(ctx.get("tier", "stranger"))) > TIER_ORDER.find(want):
					return false
			"flag":
				if not flags.has(want):
					return false
			"not_flag":
				if flags.has(want):
					return false
			_:
				return false
	return true


## Picks today's line from `lines` (docs/SOCIAL_AND_QUESTS.md §3): the lines whose `when` match
## `ctx`, minus `once` lines whose id is in `seen`; if any has a priority above 0, only the
## highest-priority ones; otherwise weighted 1 + 2 x (number of conditions). `seed_value` makes it
## deterministic (daily_seed). Returns the line Dictionary, or {} if nothing matches.
static func pick_line(lines: Array, ctx: Dictionary, seen: Dictionary, seed_value: int) -> Dictionary:
	var candidates: Array = []
	var top_priority := 0
	for raw in lines:
		if not (raw is Dictionary):
			continue
		var line: Dictionary = raw
		if bool(line.get("once", false)) and seen.has(String(line.get("id", ""))):
			continue
		var when = line.get("when", {})
		if not (when is Dictionary) or not when_matches(when, ctx):
			continue
		candidates.append(line)
		top_priority = maxi(top_priority, int(line.get("priority", 0)))
	if candidates.is_empty():
		return {}
	if top_priority > 0:
		candidates = candidates.filter(func(l): return int(l.get("priority", 0)) == top_priority)
	var total := 0
	for line in candidates:
		total += 1 + 2 * (line.get("when", {}) as Dictionary).size()
	var pick := posmod(seed_value, total)
	for line in candidates:
		pick -= 1 + 2 * (line.get("when", {}) as Dictionary).size()
		if pick < 0:
			return line
	return candidates.back()


## One string from `texts`, chosen by `seed_value`; "" if empty.
static func pick_text(texts: Array, seed_value: int) -> String:
	if texts.is_empty():
		return ""
	return String(texts[posmod(seed_value, texts.size())])


## A stable per-(npc, day, salt) number: the same all day, the same after a reload, different
## between NPCs. FNV-1a over the text, so it doesn't depend on the engine's String.hash().
static func daily_seed(npc_id: String, day: int, salt: String = "") -> int:
	var h := 2166136261
	for byte in ("%s|%d|%s" % [npc_id, day, salt]).to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h


## Replaces {key} tokens with `tokens` values.
static func fill(text: String, tokens: Dictionary) -> String:
	var out := text
	for key in tokens:
		out = out.replace("{%s}" % key, str(tokens[key]))
	return out


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
