extends RefCounted
## Slot-based inventory with stacking + hotbar (ROADMAP Phase 3).
##
## RefCounted (not Node): it's a pure data holder never added to the scene tree — player.gd
## just holds one as a field — so reference counting frees it automatically with no leak risk,
## rather than requiring an explicit .free() or scene-tree parenting a Node would need.
##
## Slots are a flat Array[Dictionary] of size TOTAL_SLOTS; slot 0..HOTBAR_SIZE-1 double as the
## hotbar (row 1 of the grid, quick-selected via number keys 1-9 per project.godot's
## hotbar_slot_N actions) exactly like Stardew/most ARPGs use their inventory's top row as the
## hotbar rather than a separate storage pool. An empty slot is {}. A stackable slot is
## {item_id, count}. A tool slot (stack_max always 1, see ItemDB.is_tool_item) additionally carries
## {durability}, e.g. {item_id="hoe", count=1, durability=37}.
##
## The actual slot-mutation logic (add/remove) is written as pure static functions operating on
## a plain Array so it's headlessly unit-testable without instancing a Node (see
## tests/test_inventory.gd) — same convention as game_camera.gd's clamp_center()/shake_offset().
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const Inventory := preload("res://scripts/inventory.gd")`.

const ItemDB := preload("res://scripts/item_db.gd")

signal changed
signal hotbar_selection_changed(index: int)

const HOTBAR_SIZE := 9
const TOTAL_SLOTS := 27  # 3 rows of 9; row 0 is the hotbar

var slots: Array = []
var selected_hotbar_index := 0


func _init() -> void:
	slots.resize(TOTAL_SLOTS)
	for i in TOTAL_SLOTS:
		slots[i] = {}


## Add `count` of a stackable item, filling existing stacks before empty slots. Tools (and any
## item with stack_max <= 1) always land in a fresh empty slot rather than "stacking". Returns
## leftover count that didn't fit (0 = fully added).
func add_item(item_id: String, count: int, durability: int = -1) -> int:
	if durability >= 0:
		var result := add_tool_to_slots(slots, item_id, durability)
		slots = result["slots"]
		changed.emit()
		return 0 if result["placed"] else count
	var result := add_to_slots(slots, item_id, count, ItemDB.stack_max(item_id))
	slots = result["slots"]
	changed.emit()
	return result["leftover"]


## Adds one tool/weapon instance with its upgrade tier (never stacks). Returns false if full.
## The "durability" key stays on the slot as the codebase's non-stacking instance marker; farming
## tools no longer wear out (2026-10-07).
func add_tool(item_id: String, tier: int = 1) -> bool:
	for i in slots.size():
		if (slots[i] as Dictionary).is_empty():
			slots[i] = {"item_id": item_id, "count": 1, "durability": maxi(ItemDB.durability_max(item_id), 1),
				"tier": clampi(tier, 1, ItemDB.MAX_TOOL_TIER)}
			changed.emit()
			return true
	return false


## Remove up to `count` of item_id from the first matching slots. Returns how many were removed.
func remove_item(item_id: String, count: int) -> int:
	var result := remove_from_slots(slots, item_id, count)
	slots = result["slots"]
	if result["removed"] > 0:
		changed.emit()
	return result["removed"]


## How many more units of item_id fit (existing stacks + empty slots). Tool instances
## (durability-tagged slots) never absorb more.
func space_for(item_id: String) -> int:
	var stack := maxi(ItemDB.stack_max(item_id), 1)
	var room := 0
	for slot in slots:
		if (slot as Dictionary).is_empty():
			room += stack
		elif slot.get("item_id", "") == item_id and not slot.has("durability"):
			room += maxi(stack - int(slot.get("count", 0)), 0)
	return room


## Whether `count` units (default 1) fit right now.
func can_add(item_id: String, count: int = 1) -> bool:
	return space_for(item_id) >= count


func is_full() -> bool:
	for slot in slots:
		if (slot as Dictionary).is_empty():
			return false
	return true


## Swaps two slots wholesale (inventory UI drag/drop). Same-item stackables merge into `to`
## instead, overflow staying in `from`.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size():
		return
	var a: Dictionary = slots[from]
	var b: Dictionary = slots[to]
	var same: bool = not a.is_empty() and not b.is_empty() and a.get("item_id") == b.get("item_id") \
		and not a.has("durability") and not b.has("durability")
	if same:
		var stack := ItemDB.stack_max(String(a["item_id"]))
		var total := int(a.get("count", 0)) + int(b.get("count", 0))
		b["count"] = mini(total, stack)
		var rest := total - int(b["count"])
		slots[to] = b
		slots[from] = {} if rest <= 0 else {"item_id": a["item_id"], "count": rest}
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()


## Directly replaces one slot (crafting/shop UIs, debug tooling).
func set_slot(index: int, slot: Dictionary) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index] = slot.duplicate(true)
	changed.emit()


## Tier (1..4) of the tool in the selected hotbar slot; 1 when untiered.
func selected_tool_tier() -> int:
	return clampi(int(get_selected_slot().get("tier", 1)), 1, ItemDB.MAX_TOOL_TIER)


func count_of(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.get("item_id", "") == item_id:
			total += int(slot.get("count", 0))
	return total


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	return slots[index]


func get_selected_slot() -> Dictionary:
	return get_slot(selected_hotbar_index)


func select_hotbar(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE or index == selected_hotbar_index:
		return
	selected_hotbar_index = index
	hotbar_selection_changed.emit(index)


## Wholesale slot replacement for the save system (Phase 4 Stage 3 — scripts/save_data.gd
## produces `slots_in` via decode_inventory, already int-normalised). Pads/truncates to
## TOTAL_SLOTS so a save from a build with a different backpack size can never leave the
## array malformed, and emits the same signals live mutations do so bound UIs refresh.
func restore(slots_in: Array, selected_index: int) -> void:
	slots = slots_in.duplicate(true)
	slots.resize(TOTAL_SLOTS)
	for i in TOTAL_SLOTS:
		if not slots[i] is Dictionary:
			slots[i] = {}
	selected_hotbar_index = clampi(selected_index, 0, HOTBAR_SIZE - 1)
	changed.emit()
	hotbar_selection_changed.emit(selected_hotbar_index)


## Reduce the selected slot's tool durability by `amount`. Returns true if the tool just broke
## (hit 0) this call. No-op (returns false) if the selected slot isn't a tool.
func damage_selected_tool(amount: int = 1) -> bool:
	var slot: Dictionary = slots[selected_hotbar_index]
	if not slot.has("durability"):
		return false
	var was_alive: bool = int(slot["durability"]) > 0
	slot["durability"] = maxi(0, int(slot["durability"]) - amount)
	slots[selected_hotbar_index] = slot
	changed.emit()
	return was_alive and slot["durability"] <= 0


## -- Pure slot math (unit tested directly; no Inventory instance required) --

static func add_to_slots(slots_in: Array, item_id: String, count: int, stack_max: int) -> Dictionary:
	var slots_out: Array = slots_in.duplicate(true)
	var remaining := count
	if stack_max > 1:
		for i in slots_out.size():
			if remaining <= 0:
				break
			var slot: Dictionary = slots_out[i]
			if slot.get("item_id", "") == item_id and not slot.has("durability"):
				var space: int = stack_max - int(slot.get("count", 0))
				if space > 0:
					var add: int = mini(space, remaining)
					slot["count"] = int(slot.get("count", 0)) + add
					slots_out[i] = slot
					remaining -= add
	for i in slots_out.size():
		if remaining <= 0:
			break
		if slots_out[i].is_empty():
			var add: int = mini(stack_max, remaining)
			slots_out[i] = {"item_id": item_id, "count": add}
			remaining -= add
	return {"slots": slots_out, "leftover": remaining}


## Tools never stack (durability makes each instance distinct) — always claims one empty slot.
## `placed` is false (slots unchanged) if there was no room.
static func add_tool_to_slots(slots_in: Array, item_id: String, durability: int) -> Dictionary:
	var slots_out: Array = slots_in.duplicate(true)
	for i in slots_out.size():
		if slots_out[i].is_empty():
			slots_out[i] = {"item_id": item_id, "count": 1, "durability": durability}
			return {"slots": slots_out, "placed": true}
	return {"slots": slots_out, "placed": false}


static func remove_from_slots(slots_in: Array, item_id: String, count: int) -> Dictionary:
	var slots_out: Array = slots_in.duplicate(true)
	var remaining := count
	for i in slots_out.size():
		if remaining <= 0:
			break
		var slot: Dictionary = slots_out[i]
		if slot.get("item_id", "") == item_id and not slot.has("durability"):
			var have: int = int(slot.get("count", 0))
			var take: int = mini(have, remaining)
			have -= take
			remaining -= take
			if have <= 0:
				slots_out[i] = {}
			else:
				slot["count"] = have
				slots_out[i] = slot
	return {"slots": slots_out, "removed": count - remaining}
