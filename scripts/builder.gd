extends Node2D
## Build/placement mode (ROADMAP.md Phase 4 Stage 2: "Basic building placement — place a
## structure blueprint, spend resources, wait 1 in-game day; simple grid-snap system").
##
## Keyboard-only flow, kept deliberately minimal to match this codebase's existing input
## conventions (settlement_select.gd's cycle+confirm; no mouse UI exists anywhere yet):
##   - "build_toggle" (B — mnemonic for Build; new action in project.godot) enters/leaves
##     placement mode. Leaving is a free cancel: nothing is spent until a placement confirms.
##   - While in mode, the player keeps walking with the normal move actions — repositioning the
##     preview IS walking, since the preview snaps to the cell grid directly ahead of the player
##     (player.gd's established _target_cell() facing convention), with multi-cell footprints
##     anchored to extend away from the player (BuildGrid.anchored_top_left).
##   - "build_cycle" (Q — adjacent to WASD so the browsing hand never leaves home position; new
##     action in project.godot) steps through the BuildingDB catalog. Number keys were NOT reused
##     here (unlike settlement_select.gd) because in gameplay they're taken by hotbar selection.
##   - "use_tool" (Space/E, reused — it's already this game's universal "confirm/act" button)
##     confirms: spends the resources, places the collidable blueprint via structures.gd, and
##     stays in build mode so several structures can be queued back-to-back; B exits.
##
## The preview is a translucent ColorRect ghost over the exact footprint — faded-green when the
## site is valid and affordable, rust-red when not — plus a small two-line label naming the
## structure, its resource cost, and the key hints. All flat palette colors, consistent with
## Phase 4's placeholder-building art scope.
##
## Energy: confirming a placement costs ENERGY_BUILD (see player.gd — priced between watering
## and chopping). Entering/cycling/canceling is free, like browsing the inventory.
##
## Wired by main.gd: bind() hands over the player/map/structures, and player.builder points back
## here so player.gd can suppress its held-use_tool swing polling while placement mode is active
## (the same press means "confirm placement" here, handled in _unhandled_input below).

const BuildingDB := preload("res://scripts/building_db.gd")
const BuildGrid := preload("res://scripts/build_grid.gd")
const ItemDB := preload("res://scripts/item_db.gd")

const CELL_SIZE := 16.0

const VALID_COLOR := Color("#95ac49", 0.45)    # faded field green — site OK, cost covered
const INVALID_COLOR := Color("#c5520f", 0.45)  # rust red — blocked site or unaffordable
const LABEL_COLOR := Color("#ffedb1")          # worn cream, same as HUD text
const LABEL_OUTLINE := Color("#281a0b")        # warm near-black, same as HUD outlines

var active := false
var catalog_index := 0

## Phase 6: the shared modal mutual-exclusion registry (scripts/modal_gate.gd), assigned by
## main.gd alongside bind(). set_active(true) refuses while any OTHER modal surface (dialogue
## box, store, shipping UI) is open — before this, pressing "B" mid-conversation turned build
## mode on underneath the open dialogue, and one "use_tool" press then advanced the dialogue AND
## confirmed a blueprint placement simultaneously (see modal_gate.gd's class doc).
var modal_gate: RefCounted = null

var _player: Node = null
var _test_map: Node = null
var _structures: Node = null
var _ids: Array[String] = []

var _preview: ColorRect
var _label: Label


func _ready() -> void:
	_ids = BuildingDB.ids()
	_preview = ColorRect.new()
	_preview.visible = false
	add_child(_preview)
	_label = Label.new()  # inherits the project theme's 8px pixel font
	_label.visible = false
	_label.add_theme_color_override("font_color", LABEL_COLOR)
	_label.add_theme_color_override("font_outline_color", LABEL_OUTLINE)
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)


## Wired by main.gd once the world exists, mirroring player.bind_world().
func bind(player: Node, test_map: Node, structures: Node) -> void:
	_player = player
	_test_map = test_map
	_structures = structures


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		set_active(not active)
	elif not active:
		return
	elif event.is_action_pressed("build_cycle"):
		catalog_index = BuildGrid.wrap_index(catalog_index, 1, _ids.size())
	elif event.is_action_pressed("use_tool"):
		confirm_placement()


## Entering build mode is refused while another modal UI is open (see modal_gate's comment
## above); leaving (value == false) is never gated — cancel must always work.
func set_active(value: bool) -> void:
	if value and modal_gate != null and modal_gate.is_any_open_except(self):
		return
	active = value and _player != null
	_preview.visible = active
	_label.visible = active


func current_id() -> String:
	if catalog_index < 0 or catalog_index >= _ids.size():
		return ""
	return _ids[catalog_index]


func _process(_delta: float) -> void:
	if not active:
		return
	var id := current_id()
	var footprint_size := BuildingDB.size_of(id)
	var top_left := _current_top_left(footprint_size)
	_preview.position = Vector2(top_left) * CELL_SIZE
	_preview.size = Vector2(footprint_size) * CELL_SIZE
	_preview.color = VALID_COLOR if _placement_ok(id, top_left, footprint_size) else INVALID_COLOR
	_label.text = "%s — %s\n[Space] place  [Q] next  [B] cancel" \
		% [BuildingDB.display_name(id), _cost_text(id)]
	_label.position = _preview.position + Vector2(0, -20)


## The footprint's top-left for the current player facing — target cell is player._target_cell()'s
## math (not called directly since it's private; same one-cell-ahead rule), anchored so the
## rectangle extends away from the player.
func _current_top_left(footprint_size: Vector2i) -> Vector2i:
	var dir: Vector2 = _player.FACING_VECTORS.get(_player.facing, Vector2(0, 1))
	var target: Vector2i = _test_map.world_to_cell(
		_player.global_position + dir * CELL_SIZE)
	return BuildGrid.anchored_top_left(target, footprint_size, _player.facing)


func _placement_ok(id: String, top_left: Vector2i, footprint_size: Vector2i) -> bool:
	return _structures.can_place(top_left, footprint_size) and _can_afford(id)


func _can_afford(id: String) -> bool:
	var cost: Dictionary = BuildingDB.cost(id)
	var have := {}
	for item_id in cost:
		have[item_id] = _player.inventory.count_of(String(item_id))
	return BuildGrid.can_afford(have, cost)


## "12 Wood, 4 Stone, 2 Scrap Metal" from the catalog cost + item display names.
func _cost_text(id: String) -> String:
	var parts: Array[String] = []
	var cost: Dictionary = BuildingDB.cost(id)
	for item_id in cost:
		parts.append("%d %s" % [int(cost[item_id]),
			String(ItemDB.get_item(String(item_id)).get("name", item_id))])
	return ", ".join(parts)


## Confirm the current preview: validity + affordability + the same positive-energy guard as
## player.use_tool(), then spend resources, place the blueprint, and pay the energy cost. Stays
## in build mode afterward (see class doc). Returns whether a blueprint was actually placed.
func confirm_placement() -> bool:
	if not active:
		return false
	var id := current_id()
	var footprint_size := BuildingDB.size_of(id)
	var top_left := _current_top_left(footprint_size)
	if not _placement_ok(id, top_left, footprint_size):
		return false
	if _player.energy <= 0.0:
		return false
	if not _structures.place_blueprint(id, top_left):
		return false
	var cost: Dictionary = BuildingDB.cost(id)
	for item_id in cost:
		_player.inventory.remove_item(String(item_id), int(cost[item_id]))
	_player.set_energy(_player.energy - _player.ENERGY_BUILD)
	return true
