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
## ## Top-level save Dictionary shape (SAVE_VERSION 1)
## {
##   "version": 1,
##   "settlement_id": "forest_edge",           # which map_layouts/*.gd this playthrough uses
##   "day": 5, "minutes_into_day": 360.0,      # DayManager clock
##   "player": {"x": ..., "y": ..., "facing": "south", "energy": 100.0,
##              "inventory": {"slots": [...], "selected_hotbar_index": 0}},
##   "map": {"tilled": ["x,y", ...]},          # player-hoed cells (test_map.gd's overlay)
##   "farm": {"plots": {"x,y": {crop_id, stage, watered}},
##            "resource_nodes": {"x,y": "tree"|"ore"}},   # nodes still STANDING (chopped/mined
##                                                        # ones are simply absent — single-hit,
##                                                        # no-respawn per Phase 3)
##   "structures": {"pending": [entry...], "completed": [entry...],
##                  "storage": {"x,y": inventory}, "chest": inventory}
##                  # entry = {building_id, kind, top_left: [x,y], size: [w,h], placed_day}
##                  # (the runtime `visual` ColorRect is deliberately dropped; load re-spawns it)
## }
## test_map.gd's _runtime_blocked overlay is intentionally NOT serialised: it is derived state
## (placed/completed building footprints), re-established on load by structures.gd re-calling
## block_cells() for each restored entry — exactly how place_blueprint() established it live,
## so the two paths can't diverge.

const SAVE_VERSION := 1


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

static func encode_plots(plots: Dictionary) -> Dictionary:
	var out := {}
	for cell in plots:
		var plot: Dictionary = plots[cell]
		out[cell_key(cell)] = {
			"crop_id": String(plot.get("crop_id", "")),
			"stage": int(plot.get("stage", 0)),
			"watered": bool(plot.get("watered", false)),
		}
	return out


static func decode_plots(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		var plot: Dictionary = data[key]
		out[parse_cell_key(String(key))] = {
			"crop_id": String(plot.get("crop_id", "")),
			"stage": int(plot.get("stage", 0)),
			"watered": bool(plot.get("watered", false)),
		}
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
		if slot.has("durability"):
			out_slot["durability"] = int(slot["durability"])
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
		if slot_dict.has("durability"):
			out_slot["durability"] = int(slot_dict["durability"])
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
