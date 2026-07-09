extends CharacterBody2D
## The player character: 4-directional movement on a CharacterBody2D, with idle / walk /
## tool-use animations per facing direction (Phase 2), plus Phase 3's real farming-tool
## dispatch, energy economy, and pass-out-at-zero transition.
##
## Tool-use (ROADMAP Phase 3): pressing "use_tool" always plays the generic swing animation
## (per CLAUDE.md's scope call — one shared swing reused for all 5 tools rather than
## per-tool PixelLab animations) and resolves ONE interaction against the tile directly ahead
## of the player, in priority order:
##   1. A mature crop there is always harvested, regardless of what's selected in the hotbar
##      (Stardew convention: harvesting isn't tool-gated).
##   2. Otherwise, the selected hotbar item decides: Hoe tills, Watering Can waters, Axe chops
##      a tree node, Pickaxe mines an ore node, a Seed item plants (consuming one seed) on
##      tilled bare soil. Anything else (Bag, empty hotbar slot, wrong tool for the tile) is a
##      no-op swing — animation plays, nothing happens, no energy spent.
## A broken tool (durability hit 0) is treated as "nothing selected" for effect purposes — it
## stays in the inventory (no repair system exists yet) but stops doing anything until a later
## phase adds one; see scripts/inventory.gd's damage_selected_tool().
##
## Holding "use_tool" down repeats the swing automatically (Stardew convention — a held tool
## button keeps tilling/watering/chopping as fast as the animation allows, not just once per
## press): _physics_process polls Input.is_action_pressed() every physics frame rather than
## reacting only to the press *event*, and re-fires use_tool() the instant the previous swing's
## using_tool lock clears, for as long as the button stays held.

const Inventory := preload("res://scripts/inventory.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const SaveData := preload("res://scripts/save_data.gd")

signal energy_changed(current: float, max_energy: float)
## Phase 5 Stage 1: fired instead of handling the interaction locally (see use_tool()'s priority
## dispatch) so scripts/dialogue_ui.gd can own opening the box — mirrors structures.gd's
## chest_toggled -> hud.toggle_chest_ui() signal wiring rather than a direct method call, keeping
## player.gd instance-testable (tests/test_player.gd) without a real DialogueUI scene existing.
signal npc_dialogue_requested(npc: Node)

## ~3.5 tiles/second at the 16px tile size — close to Stardew's walk feel.
const SPEED := 56.0
const CELL_SIZE := 16.0

## Per-action energy costs (ROADMAP Phase 3: "actions cost energy", replacing Phase 2's flat
## TOOL_USE_ENERGY_COST stub with real per-action pricing).
##
## Tuned against Stardew Valley's actual pacing rather than picked arbitrarily: base Stardew
## tool use costs ~2 energy out of a 270 starting max (~0.7% of the bar per swing), letting a
## player till/water dozens of tiles per day. The original Phase 3 pass used 4/2/1/1/5/5 against
## our 100 max energy (a 4% hit per till alone) which drained many times faster than Stardew's
## feel -- reported and fixed same-day. These values keep the same *relative* costs between
## actions (till/water heaviest, plant/harvest lightest, chop/mine heaviest of all) while
## matching Stardew's ~1% per basic action against our smaller 100-point bar.
const ENERGY_TILL := 1.0
const ENERGY_WATER := 1.0
const ENERGY_PLANT := 0.5
const ENERGY_HARVEST := 0.5
const ENERGY_CHOP := 1.5
const ENERGY_MINE := 1.5
## Phase 4 Stage 2: confirming a building placement (scripts/builder.gd). Priced between
## watering (1.0) and chopping (1.5) — staking out a construction site is real physical work,
## heavier than a watering pass but lighter than felling a tree, and it's a one-off per building
## rather than a per-tile repeated action, so it shouldn't dominate the day's energy budget.
const ENERGY_BUILD := 1.25

const FACINGS := ["south", "north", "east", "west"]
const FACING_VECTORS := {
	"south": Vector2(0, 1),
	"north": Vector2(0, -1),
	"east": Vector2(1, 0),
	"west": Vector2(-1, 0),
}

var facing := "south"
var max_energy := 100.0
var energy := max_energy
var using_tool := false

## Till-and-advance stepping (see class doc): a short, grid-snapped move to the next cell,
## queued between swings when a direction is held alongside "use_tool" so holding both
## advances tile-by-tile like Stardew's auto-work-and-walk, instead of repeating in place.
var _stepping := false
var _step_target := Vector2.ZERO

## Bound by main.gd once the world exists (see bind_world()).
var farm: Node = null
var test_map: Node = null
var structures: Node = null
## Phase 4 Stage 2: the build/placement-mode node (scripts/builder.gd), also bound by main.gd.
## While its mode is active, "use_tool" means "confirm placement" (handled there), so the
## held-swing polling below stands down — see _in_build_mode().
var builder: Node = null
## Phase 5 Stage 1: the NPC roster (scripts/npcs.gd) — bound by main.gd like farm/test_map/
## structures above, used by use_tool()'s priority dispatch to find an NPC directly ahead.
var npcs: Node = null
## Phase 5 Stage 1: the dialogue box (scripts/dialogue_ui.gd), bound DIRECTLY by main.gd
## (not via bind_world) the same way player.builder is — while it's open, _physics_process
## freezes entirely (see _in_dialogue()) and dialogue_ui.gd owns "use_tool" itself (via its own
## _unhandled_input) to advance/close the conversation.
var dialogue_ui: Node = null
var inventory: Inventory = Inventory.new()

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_play("idle")
	_give_starting_loadout()


func _physics_process(_delta: float) -> void:
	if using_tool:
		velocity = Vector2.ZERO
		return
	# Phase 5 Stage 1: a conversation freezes the player completely (movement AND tool-swing
	# polling) for as long as it's open — dialogue_ui.gd owns "use_tool" itself via its own
	# _unhandled_input to advance/close, so this loop must not also react to the same held key.
	# Checked ahead of everything below (not folded into the use_tool-repeat branch's condition
	# the way _in_build_mode() is) specifically because build mode still lets the player walk to
	# reposition the preview, but a dialogue must NOT — the player should read as genuinely stuck
	# in the conversation, not free to wander off mid-sentence.
	if _in_dialogue():
		velocity = Vector2.ZERO
		return
	if _stepping:
		_process_step()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_pressed("use_tool") and not _in_build_mode():
		# Held-button repeat (see class doc): re-triggers every physics frame the button is
		# down and the previous swing has finished, since use_tool() re-locks using_tool
		# immediately and this branch is unreachable again until that lock clears. Facing
		# follows a held direction so the swing lands on the tile you're steering toward, not
		# wherever you happened to be facing before.
		velocity = Vector2.ZERO
		if input != Vector2.ZERO:
			facing = facing_from_input(input, facing)
		use_tool()
		return
	velocity = input * SPEED
	move_and_slide()
	facing = facing_from_input(input, facing)
	_play("walk" if input != Vector2.ZERO else "idle")


## Advances one grid cell toward _step_target at normal walk speed, then hands control back to
## the use_tool-repeat branch above. Bails out early (rather than getting stuck) if something
## physically blocks the step, e.g. rubble or a resource node revealed by the tile just cleared.
func _process_step() -> void:
	var to_target := _step_target - global_position
	if to_target.length() <= 1.0:
		global_position = _step_target
		_stepping = false
		return
	velocity = to_target.normalized() * SPEED
	move_and_slide()
	_play("walk")
	if get_slide_collision_count() > 0:
		_stepping = false


func _unhandled_input(event: InputEvent) -> void:
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_slot_%d" % (i + 1)):
			inventory.select_hotbar(i)


## Wired by main.gd once the farm/map/structures exist, so player.gd can stay instance-testable
## on its own (tests/test_player.gd) without needing a full scene. structures_node/npcs_node are
## optional (default null) so existing callers/tests keep working unchanged.
func bind_world(farm_node: Node, map_node: Node, structures_node: Node = null,
		npcs_node: Node = null) -> void:
	farm = farm_node
	test_map = map_node
	structures = structures_node
	npcs = npcs_node


## Plays the shared swing animation and resolves the tile interaction. Locks movement for the
## animation's duration exactly like the Phase 2 stub did.
func use_tool() -> void:
	if energy <= 0.0:
		return
	# Phase 4: chest interaction is instant (no energy cost, no tool-swing lock/animation) and
	# takes priority over farming — matches Stardew's "activate button opens a chest" convention
	# rather than routing through the hotbar-tool dispatch below. Stage 2 generalized "the chest"
	# to any storage cell (layout chest OR a completed player-built Storage Shed), so the target
	# cell is passed through for structures.gd to resolve which Inventory lives there.
	if structures != null and test_map != null and structures.is_chest_at(_target_cell()):
		structures.interact_chest(_target_cell())
		return
	# Phase 4 Stage 3: the farmhouse bed — same instant, energy-free, queue-jumping interaction
	# shape as the chest above. Sleeping ends the day (auto-saving as it does — see checklist
	# item "Auto-save at end of day"), so it deliberately never routes through the tool dispatch.
	if structures != null and test_map != null and structures.is_bed_at(_target_cell()):
		_sleep_in_bed()
		return
	# Phase 5 Stage 1: an NPC directly ahead — same instant, energy-free, queue-jumping shape as
	# the chest/bed above, but the interaction itself (opening the dialogue box) is handed off via
	# a signal rather than resolved here, since it belongs to scripts/dialogue_ui.gd (see the
	# signal's own doc comment above for why).
	if npcs != null and test_map != null:
		var npc: Node = npcs.npc_at(_target_cell())
		if npc != null:
			npc_dialogue_requested.emit(npc)
			return
	using_tool = true
	velocity = Vector2.ZERO
	_play("tool")
	if farm != null and test_map != null:
		_interact(_target_cell())


## Applies a delta to energy (clamped 0..max) and fires pass-out if it just crossed to zero.
func set_energy(value: float) -> void:
	var result := apply_energy_delta(energy, max_energy, value - energy)
	energy = result["energy"]
	energy_changed.emit(energy, max_energy)
	if result["passed_out"]:
		_pass_out()


## Stardew's "passing out at zero energy loses the rest of the day" rule (ROADMAP Phase 3),
## via DayManager's skip_to_next_morning(). Waking up restores full energy, same as collapsing
## in Stardew. Distinct from _sleep_in_bed() below (Phase 4's real bed): collapsing does NOT
## auto-save — only deliberately going to bed does, per the Stage 3 checklist item.
func _pass_out() -> void:
	DayManager.skip_to_next_morning()
	energy = max_energy
	energy_changed.emit(energy, max_energy)


## Phase 4 Stage 3: sleeping in the farmhouse bed (structures.is_bed_at). Ends the day through
## the same skip_to_next_morning() signal path pass-out uses (so crop growth, construction
## completion, etc. all fire identically), restores full energy ("waking up rested", matching
## _pass_out's rule), THEN auto-saves — deliberately after the day advance, so the save captures
## the fresh morning the player will wake into on reload, not the stale end of the old day.
## GameState.save_game emits game_saved on success, which the HUD's "WORLD SAVED" notice rides.
func _sleep_in_bed() -> void:
	DayManager.skip_to_next_morning()
	energy = max_energy
	energy_changed.emit(energy, max_energy)
	GameState.save_game(self, test_map, farm, structures)


## True while scripts/builder.gd's placement mode is active — the use_tool button then belongs
## to placement confirmation (handled in builder.gd's _unhandled_input), not tool swings.
func _in_build_mode() -> bool:
	return builder != null and bool(builder.active)


## True while scripts/dialogue_ui.gd's box is open — see _physics_process's early-return.
func _in_dialogue() -> bool:
	return dialogue_ui != null and bool(dialogue_ui.active)


## The logical cell directly ahead of the player, in the current facing direction.
func _target_cell() -> Vector2i:
	var dir: Vector2 = FACING_VECTORS.get(facing, Vector2(0, 1))
	return test_map.world_to_cell(global_position + dir * CELL_SIZE)


func _interact(cell: Vector2i) -> void:
	if farm.can_harvest(cell):
		var result: Dictionary = farm.harvest(cell)
		if not result.is_empty():
			_grant_item(result)
			set_energy(energy - ENERGY_HARVEST)
		return

	var slot := inventory.get_selected_slot()
	var item_id := String(slot.get("item_id", ""))
	if slot.has("durability") and int(slot["durability"]) <= 0:
		item_id = ""  # broken tool: swing does nothing

	match item_id:
		"hoe":
			if farm.can_till(cell) and farm.till(cell):
				set_energy(energy - ENERGY_TILL)
				inventory.damage_selected_tool()
		"watering_can":
			if farm.can_water(cell) and farm.water(cell):
				set_energy(energy - ENERGY_WATER)
				inventory.damage_selected_tool()
		"axe":
			if farm.can_chop(cell):
				for result in farm.chop(cell):
					_grant_item(result)
				set_energy(energy - ENERGY_CHOP)
				inventory.damage_selected_tool()
		"pickaxe":
			if farm.can_mine(cell):
				for result in farm.mine(cell):
					_grant_item(result)
				set_energy(energy - ENERGY_MINE)
				inventory.damage_selected_tool()
		_:
			if ItemDB.is_seed(item_id) and farm.can_plant(cell):
				var crop_id := String(ItemDB.get_item(item_id).get("crop_id", ""))
				if farm.plant(cell, crop_id):
					inventory.remove_item(item_id, 1)
					set_energy(energy - ENERGY_PLANT)


## -- Save/load (Phase 4 Stage 3; see scripts/save_data.gd's class doc for the shape) --

func save_state() -> Dictionary:
	return {
		# Vector2 split into JSON-friendly scalars.
		"x": global_position.x,
		"y": global_position.y,
		"facing": facing,
		"energy": energy,
		"inventory": SaveData.encode_inventory(inventory.slots, inventory.selected_hotbar_index),
	}


func load_state(data: Dictionary) -> void:
	global_position = Vector2(float(data.get("x", global_position.x)),
		float(data.get("y", global_position.y)))
	velocity = Vector2.ZERO
	if String(data.get("facing", "")) in FACINGS:
		facing = String(data["facing"])
	# Direct assign + emit, not set_energy(): restoring a saved value is not a gameplay energy
	# change and must never re-trigger the pass-out rule (set_energy's crossing check would be
	# safe for the values a bed save writes, but load shouldn't depend on that).
	energy = clampf(float(data.get("energy", max_energy)), 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
	var inventory_data = data.get("inventory", {})
	if inventory_data is Dictionary and not (inventory_data as Dictionary).is_empty():
		var decoded := SaveData.decode_inventory(inventory_data)
		inventory.restore(decoded["slots"], int(decoded["selected_hotbar_index"]))
	_play("idle")


## Overflow (backpack full) is silently lost — Phase 3 has no ground-drop system yet; a known,
## documented limitation (see the Phase 3 report) rather than an oversight.
func _grant_item(result: Dictionary) -> void:
	inventory.add_item(String(result.get("item_id", "")), int(result.get("count", 0)))


## Starting loadout: the 5 tools in hotbar slots 0-4 (fixed order matching the checklist), a
## handful of Mutant Potato seeds in slot 5 to plant immediately. Everything else starts empty.
func _give_starting_loadout() -> void:
	for tool_id in ["hoe", "watering_can", "axe", "pickaxe", "bag"]:
		inventory.add_item(tool_id, 1, ItemDB.durability_max(tool_id))
	inventory.add_item("seed_mutant_potato", 5)


## Pure facing rule (testable headlessly): horizontal input wins on diagonals (Stardew-style
## side-facing bias), and facing is retained when input stops so idle keeps the last direction.
static func facing_from_input(input: Vector2, current: String) -> String:
	if input == Vector2.ZERO:
		return current
	if absf(input.x) >= absf(input.y) and input.x != 0.0:
		return "east" if input.x > 0.0 else "west"
	return "south" if input.y > 0.0 else "north"


## Pure energy math (testable headlessly, no Node/scene required): clamps current+delta into
## [0, max_energy] and reports whether this change is the one that crossed from positive energy
## down to exactly zero (i.e. should trigger a pass-out) — a delta applied while already at 0
## does NOT re-trigger, matching set_energy()'s guard.
static func apply_energy_delta(current: float, max_energy_value: float, delta: float) -> Dictionary:
	var new_energy := clampf(current + delta, 0.0, max_energy_value)
	var passed_out := current > 0.0 and new_energy <= 0.0
	return {"energy": new_energy, "passed_out": passed_out}


func _play(action: String) -> void:
	var animation := "%s_%s" % [action, facing]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation) \
			and (sprite.animation != animation or not sprite.is_playing()):
		sprite.play(animation)


func _on_sprite_animation_finished() -> void:
	if using_tool:
		using_tool = false
		# Till-and-advance (see class doc / _process_step()): if a direction is still held
		# alongside "use_tool" when the swing finishes, queue a one-cell step in that direction
		# instead of immediately re-swinging in place — the next _physics_process tick will
		# fire another swing automatically once the step completes, chaining tile-by-tile for
		# as long as both are held.
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_pressed("use_tool") and input != Vector2.ZERO:
			var dir: Vector2 = FACING_VECTORS.get(facing, Vector2.ZERO)
			_step_target = global_position + dir * CELL_SIZE
			_stepping = true
		else:
			_play("idle")
