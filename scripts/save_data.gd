extends RefCounted
## Pure save-file serialisation logic (ROADMAP.md Phase 4 Stage 3: "Auto-save at end of day...
## FileAccess + JSON serialisation"). Every function here is static and operates on plain
## values — no Nodes, no scene tree, no file I/O — so the whole encode/decode surface is
## headlessly unit-testable (tests/test_save_data.gd), same convention as farm_grid.gd/
## build_grid.gd. The stateful side (gathering live node state, FileAccess reads/writes,
## the resume-vs-new-game decision) lives in the GameState autoload (scripts/game_state.gd).
##
## ## Why the encode/decode pairs exist at all
## The runtime state uses types JSON can't carry: Vector2i Dictionary keys (plots, tilled
## cells, resource nodes, storage inventories) and Vector2i fields (structure footprints).
## Encoding turns Vector2i keys into "x,y" strings and Vector2i fields into [x, y] arrays;
## decoding reverses that AND re-normalises the numeric types JSON round-trips as floats
## (JSON.parse_string returns 3.0 where 3 was written) back to the ints the game logic
## compares with `==` — stage counts, item counts, durability, placed_day would all silently
## mismatch without this.
##
## ## Top-level save Dictionary shape (SAVE_VERSION 2 — the zone split)
## {
##   "version": 2,
##   "settlement_id": "forest_edge",           # which start this playthrough uses (selects the
##                                             # farm layout AND the standard/riverside variant
##                                             # of each other zone — settlement_db.gd's
##                                             # layout_for_zone)
##   "day": 5, "minutes_into_day": 360.0,      # DayManager clock
##   "saved_unix": 1783728000,                 # OPTIONAL wall-clock write stamp (2026-07-11,
##                                             # multi-slot) — Load-screen ordering only, never
##                                             # world state; absent in older saves (treated 0)
##   "player": {"x": ..., "y": ..., "facing": "south", "energy": 100.0, "credits": 57,
##              "current_zone": "town",        # which zone x/y (world-space) stands in
##              "inventory": {"slots": [...], "selected_hotbar_index": 0}},
##   "zones": {                                # one uniform section per always-instantiated
##     "farm":  {"map": ..., "farm": ..., "structures": ...},   # zone (v1's top-level map/farm/
##     "path":  {"map": ..., "farm": ..., "structures": ...},   # structures sections, per zone)
##     "town":  {"map": ..., "farm": ..., "structures": ...},
##     "ranch": {"map": ..., "farm": ..., "structures": ...}
##   },
##   "settlers": {                             # Phase 8 Stages 3-4 — additive, no version bump (see
##     "next_arrival_day": 12,                 # its own encode/decode section below)
##     "next_salary_day": 14,
##     "roster": [{"id", "name", "home_cell": [x,y], "assigned_building": {...}}, ...],
##     "pending_visitor": {} | {"id", "name", "home_cell": [x,y]}
##   }
##   "story_flags": {                          # scripted beats — additive, no version bump
##     "day_28_food_shortage_seen": true
##   }
##   "animals": {"animals": [{"animal_id", "housing", "housing_index", "last_care_day"}, ...]}
##   "affinity": {                             # Phase 7 Stage 3 — additive, no version bump
##     "values": {npc_id: 0-10},               # the relationship track itself
##     "last_talked_day": {npc_id: day}        # the once-per-day talk-tick cap
##   }
## }
## Per-zone section shapes (unchanged from v1, just nested per zone — the encoders below are
## reused as-is, called 4x instead of once):
##   "map": {"tilled": ["x,y", ...]}           # player-hoed cells (test_map.gd's overlay)
##   "farm": {"plots": {"x,y": {crop_id, stage, watered}},
##            "resource_nodes": {"x,y": "tree"|"ore"}}   # nodes still STANDING (chopped/mined
##                                                       # ones are simply absent — single-hit,
##                                                       # no-respawn per Phase 3)
##   "structures": {"pending": [entry...], "completed": [entry...],
##                  "storage": {"x,y": inventory}, "chest": inventory,
##                  "shipping": {"contents": {item_id: count},
##                               "history": [{day, items: {item_id: count}, total}]}}
##                  # entry = {building_id, kind, top_left: [x,y], size: [w,h], placed_day}
##                  # (the runtime `visual` node is deliberately dropped; load re-spawns it)
## Zones with no farmland/chest/box (path/town/ranch today) serialise empty defaults in the
## same uniform shape — keeps game_state.gd's gather loop branch-free and stays
## forward-compatible if e.g. a town garden patch is ever added.
## test_map.gd's _runtime_blocked overlay is intentionally NOT serialised: it is derived state
## (placed/completed building footprints), re-established on load by structures.gd re-calling
## block_cells() for each restored entry — exactly how place_blueprint() established it live,
## so the two paths can't diverge.
##
## v1 saves are INVALIDATED, not migrated (parse_save's version check returns {} for them, so
## they fall through to the new-game picker): the zone split moved Town/Ranch into new local
## coordinate frames, and per Sarvesh's explicit call the pre-split save files are deleted
## rather than left as permanently-unloadable clutter — see the Stage 1/2 plan notes.

const SAVE_VERSION := 2


## -- Vector2i <-> JSON-safe key/array forms --

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


## -- Tilled-cell overlay (test_map.gd's _tilled keys) --

static func encode_cells(cells: Array) -> Array:
	var out: Array = []
	for cell in cells:
		out.append(cell_key(cell))
	return out


static func decode_cells(data: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in data:
		out.append(parse_cell_key(String(key)))
	return out


## -- Farm plots (farm.gd's _plots: cell -> {crop_id, stage, watered}) --

## v2 plots (2026-10-07) add growth/fertilizer/dead; a pre-v2 plot simply lacks them and
## farm_grid.gd's normalize_plot() fills them in from "stage".
static func encode_plots(plots: Dictionary) -> Dictionary:
	var out := {}
	for cell in plots:
		var plot: Dictionary = plots[cell]
		var entry := {
			"crop_id": String(plot.get("crop_id", "")),
			"stage": int(plot.get("stage", 0)),
			"watered": bool(plot.get("watered", false)),
		}
		if plot.has("growth"):
			entry["growth"] = int(plot["growth"])
		if int(plot.get("fertilizer", 0)) > 0:
			entry["fertilizer"] = int(plot["fertilizer"])
		if bool(plot.get("dead", false)):
			entry["dead"] = true
		out[cell_key(cell)] = entry
	return out


static func decode_plots(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		var plot: Dictionary = data[key]
		var entry := {
			"crop_id": String(plot.get("crop_id", "")),
			"stage": int(plot.get("stage", 0)),
			"watered": bool(plot.get("watered", false)),
		}
		if plot.has("growth"):
			entry["growth"] = int(plot["growth"])
		if plot.has("fertilizer"):
			entry["fertilizer"] = int(plot["fertilizer"])
		if plot.has("dead"):
			entry["dead"] = bool(plot["dead"])
		out[parse_cell_key(String(key))] = entry
	return out


## -- Generic cell -> int maps (fertilised soil, etc.) --

static func encode_cell_ints(values: Dictionary) -> Dictionary:
	var out := {}
	for cell in values:
		out[cell_key(cell)] = int(values[cell])
	return out


static func decode_cell_ints(data) -> Dictionary:
	var out := {}
	if not (data is Dictionary):
		return out
	for key in data:
		out[parse_cell_key(String(key))] = int(data[key])
	return out


## -- Resource nodes (farm.gd's _resource_nodes: cell -> "tree"|"ore") --

static func encode_resource_nodes(nodes: Dictionary) -> Dictionary:
	var out := {}
	for cell in nodes:
		out[cell_key(cell)] = String(nodes[cell])
	return out


static func decode_resource_nodes(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		out[parse_cell_key(String(key))] = String(data[key])
	return out


## -- Inventory (inventory.gd's slots array + hotbar selection) --
## A slot is {} | {item_id, count} | {item_id, count, durability} — already JSON-friendly
## except for JSON's float round-trip on the int fields (see class doc).

## Optional per-slot integer fields that round-trip: tool instance marker, upgrade tier,
## watering-can level, item quality, weapon ammo loaded.
const SLOT_INT_EXTRAS: Array[String] = ["durability", "tier", "water", "quality", "ammo"]


static func encode_inventory(slots: Array, selected_hotbar_index: int) -> Dictionary:
	var out_slots: Array = []
	for slot in slots:
		if slot.is_empty():
			out_slots.append({})
			continue
		var out_slot := {
			"item_id": String(slot.get("item_id", "")),
			"count": int(slot.get("count", 0)),
		}
		for extra in SLOT_INT_EXTRAS:
			if slot.has(extra):
				out_slot[extra] = int(slot[extra])
		out_slots.append(out_slot)
	return {"slots": out_slots, "selected_hotbar_index": selected_hotbar_index}


static func decode_inventory(data: Dictionary) -> Dictionary:
	var out_slots: Array = []
	for slot in data.get("slots", []):
		var slot_dict: Dictionary = slot
		if slot_dict.is_empty():
			out_slots.append({})
			continue
		var out_slot := {
			"item_id": String(slot_dict.get("item_id", "")),
			"count": int(slot_dict.get("count", 0)),
		}
		for extra in SLOT_INT_EXTRAS:
			if slot_dict.has(extra):
				out_slot[extra] = int(slot_dict[extra])
		out_slots.append(out_slot)
	return {
		"slots": out_slots,
		"selected_hotbar_index": int(data.get("selected_hotbar_index", 0)),
	}


## -- Runtime-placed structures (structures.gd's _pending/_completed entries) --
## The live entry's `visual` (a ColorRect) is deliberately dropped — structures.gd's
## load_state() re-spawns it through the same _spawn_footprint_body() the live placement path
## uses, then re-attaches it to the decoded entry.

static func encode_structure_entry(entry: Dictionary) -> Dictionary:
	var top_left: Vector2i = entry["top_left"]
	var size: Vector2i = entry["size"]
	return {
		"building_id": String(entry.get("building_id", "")),
		"kind": String(entry.get("kind", "")),
		"top_left": [top_left.x, top_left.y],
		"size": [size.x, size.y],
		"placed_day": int(entry.get("placed_day", 1)),
	}


static func decode_structure_entry(data: Dictionary) -> Dictionary:
	var top_left: Array = data.get("top_left", [0, 0])
	var size: Array = data.get("size", [1, 1])
	return {
		"building_id": String(data.get("building_id", "")),
		"kind": String(data.get("kind", "")),
		"top_left": Vector2i(int(top_left[0]), int(top_left[1])),
		"size": Vector2i(int(size[0]), int(size[1])),
		"placed_day": int(data.get("placed_day", 1)),
	}


## -- Shipping box (structures.gd's shipping_contents + sale_history, Phase 5 Stage 3) --
## contents keys are item-id Strings (already JSON-safe); the work here is the usual int
## re-normalisation of counts/day/total after JSON's float round-trip (see class doc), plus
## dropping any malformed history rows rather than letting them crash a later reader.

static func encode_shipping(contents: Dictionary, history: Array) -> Dictionary:
	var contents_out := {}
	for item_id in contents:
		contents_out[String(item_id)] = int(contents[item_id])
	var history_out: Array = []
	for entry in history:
		var items_out := {}
		for item_id in entry.get("items", {}):
			items_out[String(item_id)] = int(entry["items"][item_id])
		history_out.append({
			"day": int(entry.get("day", 1)),
			"items": items_out,
			"total": int(entry.get("total", 0)),
		})
	return {"contents": contents_out, "history": history_out}


static func decode_shipping(data: Dictionary) -> Dictionary:
	var contents := {}
	for item_id in data.get("contents", {}):
		contents[String(item_id)] = int(data["contents"][item_id])
	var history: Array = []
	for entry in data.get("history", []):
		if not entry is Dictionary:
			continue
		var items := {}
		for item_id in entry.get("items", {}):
			items[String(item_id)] = int(entry["items"][item_id])
		history.append({
			"day": int(entry.get("day", 1)),
			"items": items,
			"total": int(entry.get("total", 0)),
		})
	return {"contents": contents, "history": history}


## -- Settlers (scripts/settlers.gd's roster/pending_visitor/next_arrival_day, Phase 8 Stage 3) --
## A new additive top-level "settlers" key, parallel to "zones" — no SAVE_VERSION bump (see class
## doc: parse_save's exact-match check isn't touched, an old save simply decodes this new key as
## its empty default via decode_settlers' own .get() fallbacks). A roster/pending-visitor entry
## carries a Vector2i home_cell (JSON-array-encoded like every other cell field here) and an
## assigned_building reference. Its nested top_left Vector2i is encoded explicitly so assignment
## survives JSON round-trips without leaking engine-only types into the save file.

static func encode_settler_entry(entry: Dictionary) -> Dictionary:
	var home_cell: Vector2i = entry.get("home_cell", Vector2i.ZERO)
	return {
		"id": String(entry.get("id", "")),
		"name": String(entry.get("name", "")),
		"home_cell": [home_cell.x, home_cell.y],
		"assigned_building": encode_assignment(entry.get("assigned_building", {})),
	}


static func decode_settler_entry(data: Dictionary) -> Dictionary:
	var home_cell: Array = data.get("home_cell", [0, 0])
	return {
		"id": String(data.get("id", "")),
		"name": String(data.get("name", "")),
		"home_cell": Vector2i(int(home_cell[0]), int(home_cell[1])),
		"assigned_building": decode_assignment(data.get("assigned_building", {})),
	}


static func encode_assignment(data) -> Dictionary:
	if not data is Dictionary or (data as Dictionary).is_empty():
		return {}
	var assignment: Dictionary = data
	var top_left = assignment.get("top_left", Vector2i.ZERO)
	var encoded := assignment.duplicate(true)
	if top_left is Vector2i:
		encoded["top_left"] = [top_left.x, top_left.y]
	return encoded


static func decode_assignment(data) -> Dictionary:
	if not data is Dictionary or (data as Dictionary).is_empty():
		return {}
	var assignment: Dictionary = data.duplicate(true)
	var top_left = assignment.get("top_left", null)
	if top_left is Array and top_left.size() == 2:
		assignment["top_left"] = Vector2i(int(top_left[0]), int(top_left[1]))
	return assignment


static func encode_settlers(next_arrival_day: int, roster: Array, pending_visitor: Dictionary,
		next_salary_day: int = 7) -> Dictionary:
	var roster_out: Array = []
	for entry in roster:
		roster_out.append(encode_settler_entry(entry))
	var pending_out := {} if pending_visitor.is_empty() else encode_settler_entry(pending_visitor)
	return {
		"next_arrival_day": next_arrival_day,
		"next_salary_day": next_salary_day,
		"roster": roster_out,
		"pending_visitor": pending_out,
	}


static func decode_settlers(data: Dictionary) -> Dictionary:
	# Typed Array[Dictionary], not a plain Array: scripts/settlers.gd's `roster` field is declared
	# Array[Dictionary], and Godot 4 refuses to assign a plain (untyped) Array into a typed Array
	# variable even when every element already matches — this must be typed at the source.
	var roster_out: Array[Dictionary] = []
	for entry_data in data.get("roster", []):
		roster_out.append(decode_settler_entry(entry_data))
	var pending_data: Dictionary = data.get("pending_visitor", {})
	var pending_out := {} if pending_data.is_empty() else decode_settler_entry(pending_data)
	return {
		"next_arrival_day": int(data.get("next_arrival_day", 1)),
		"next_salary_day": int(data.get("next_salary_day", 7)),
		"roster": roster_out,
		"pending_visitor": pending_out,
	}


## -- Scripted story-beat flags --
## Kept as an additive section so saves written before the Day-28 beat simply decode the
## new flag as false. The flag is state, not dialogue traversal data: it prevents a day-start
## trigger from replaying after a save/load.

static func encode_story_flags(day_28_food_shortage_seen: bool) -> Dictionary:
	return {"day_28_food_shortage_seen": day_28_food_shortage_seen}


static func decode_story_flags(data: Dictionary) -> Dictionary:
	return {
		"day_28_food_shortage_seen": bool(data.get("day_28_food_shortage_seen", false)),
	}


## Livestock state is already JSON-safe after this normalisation pass. Keeping the pair here
## makes the additive save section independently unit-testable and keeps malformed rows harmless.
static func encode_animals(data: Dictionary) -> Dictionary:
	var out: Array = []
	for raw in data.get("animals", []):
		if not raw is Dictionary:
			continue
		out.append({
			"animal_id": String(raw.get("animal_id", "")),
			"housing": String(raw.get("housing", "")),
			"housing_index": int(raw.get("housing_index", -1)),
			"last_care_day": int(raw.get("last_care_day", 0)),
		})
	return {"animals": out}


static func decode_animals(data: Dictionary) -> Dictionary:
	return encode_animals(data if data is Dictionary else {})


## -- Affinity (scripts/affinity.gd's per-NPC relationship track, Phase 7 Stage 3) --
## Another additive top-level key with no SAVE_VERSION bump, following "settlers"/"story_flags"/
## "animals" exactly (see class doc: an old save simply decodes this section as its empty default
## through the .get() fallbacks below). Structurally the closest sibling is encode_story_flags —
## a minimal flat dict, no Vector2i or nested entry shapes to convert — with the one novelty
## that this is the project's FIRST save dict keyed directly by npc_id (settlers.roster is an
## array whose entries carry their own "id"). Keys therefore pass through as plain Strings; only
## the values need JSON's float round-trip normalised back to int (same rule as every other
## numeric field here — a stage/count/day compared with `==` would silently mismatch otherwise).
##
## Both of affinity.gd's dicts live in this ONE section rather than two sibling top-level keys:
## they are halves of the same per-NPC relationship record (the value, and the once-per-day talk
## bookkeeping that produced it), and splitting them would let a partial restore resurrect a
## value whose daily cap had been forgotten — allowing a second same-day tick after a reload.

## 2026-10-08 (Milestone B, social): the section now holds friendship POINTS (0-2500, 250 to a
## heart, under "points") instead of whole hearts (the old "values"), plus the gift bookkeeping
## (last gift day, this week's gift count), the gift reactions the player has discovered, and the
## ids of once-only dialogue lines already seen. A save from before has only "values": its hearts
## decode as hearts x POINTS_PER_HEART, so nobody's friendship is lost.
const POINTS_PER_HEART := 250

static func encode_affinity(points: Dictionary, last_talked_day: Dictionary,
		extra: Dictionary = {}) -> Dictionary:
	var points_out := {}
	for npc_id in points:
		points_out[String(npc_id)] = int(points[npc_id])
	var talked_out := {}
	for npc_id in last_talked_day:
		talked_out[String(npc_id)] = int(last_talked_day[npc_id])
	var gift_day_out := {}
	var raw_gift_day = extra.get("last_gift_day", {})
	if raw_gift_day is Dictionary:
		for npc_id in raw_gift_day:
			gift_day_out[String(npc_id)] = int(raw_gift_day[npc_id])
	var week_out := {}
	var raw_week = extra.get("gift_week", {})
	if raw_week is Dictionary:
		for npc_id in raw_week:
			var pair = raw_week[npc_id]
			if pair is Array and (pair as Array).size() == 2:
				week_out[String(npc_id)] = [int(pair[0]), int(pair[1])]
	var known_out := {}
	var raw_known = extra.get("known_gifts", {})
	if raw_known is Dictionary:
		for npc_id in raw_known:
			var tastes = raw_known[npc_id]
			if not (tastes is Dictionary):
				continue
			var entry := {}
			for item_id in tastes:
				entry[String(item_id)] = String(tastes[item_id])
			known_out[String(npc_id)] = entry
	var seen_out: Array = []
	var raw_seen = extra.get("seen_lines", [])
	if raw_seen is Array:
		for line_id in raw_seen:
			seen_out.append(String(line_id))
	return {"points": points_out, "last_talked_day": talked_out, "last_gift_day": gift_day_out,
		"gift_week": week_out, "known_gifts": known_out, "seen_lines": seen_out}


static func decode_affinity(data: Dictionary) -> Dictionary:
	var raw_points = data.get("points", null)
	var points := {}
	if raw_points is Dictionary:
		points = raw_points
	else:
		var legacy = data.get("values", {})
		if legacy is Dictionary:
			for npc_id in legacy:
				points[npc_id] = int(legacy[npc_id]) * POINTS_PER_HEART
	var raw_talked = data.get("last_talked_day", {})
	return encode_affinity(points, raw_talked if raw_talked is Dictionary else {}, data)


## -- Top-level assembly / parsing --

## Stamps the version onto the gathered per-system sections. `sections` must already be fully
## JSON-safe (each node's save_state() guarantees that via the encoders above).
static func build_save(sections: Dictionary) -> Dictionary:
	var out := sections.duplicate(true)
	out["version"] = SAVE_VERSION
	return out


## Parses save-file text back into the save Dictionary. Returns {} for anything unusable —
## unparseable JSON, a non-Dictionary root, a missing/mismatched version, or a missing
## settlement_id — so callers get a single is_empty() check instead of a validation cascade.
## (An unknown-but-well-formed settlement_id is GameState's job to reject; this layer doesn't
## know the settlement roster.)
static func parse_save(text: String) -> Dictionary:
	# A JSON instance rather than the static JSON.parse_string(): the static helper push_error()s
	# on bad input, and "the save file is corrupt" is an expected, handled condition here (the
	# caller falls back to a fresh game / the picker), not an engine error worth log noise —
	# tests/test_save_data.gd feeds this garbage on purpose.
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	if int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	if String(data.get("settlement_id", "")) == "":
		return {}
	return data
