extends Node2D
## Phase 4 building layer: spawns the farmhouse, mayor's fortified house, Marta's store, settler
## shacks, storage chest, and bulletin board as real, collidable placeholder volumes — one
## StaticBody2D + one flat-color visual per building, sized to its footprint (top_left + size in
## cells, from scripts/map_layouts/*.gd's buildings() list). Same "flat-color placeholder,
## StaticBody2D + ColorRect" pattern as scripts/farm.gd's _spawn_resource_prop, generalized from
## a fixed 1x1 tree/ore footprint to an arbitrary rectangle.
##
## ROADMAP.md Phase 4 scope: these are placeholder volumes, not full art/interiors — no NPCs live
## in them yet (Phase 5), no interiors exist, and only the chest is actually interactable this
## session. The bulletin board is deliberately inert (no quest system exists yet).
##
## Expected in the scene tree as a child of TestMap (see scenes/test_map.tscn), sibling to Farm,
## so get_parent() is the TestMap node whose `layout` this reads building data from — same
## ordering guarantee TestMap.gd documents (`layout` is set in TestMap._enter_tree(), which runs
## before this node's _ready() since _enter_tree is top-down and _ready is bottom-up).
##
## Phase 4 Stage 2 ("Basic building placement") extends this same node to also own RUNTIME-placed
## buildings, not just layout-authored ones: scripts/builder.gd's placement mode calls
## can_place()/place_blueprint() here, a placed blueprint is immediately a real collidable body
## (rendered translucent blueprint-blue so it reads as "under construction"), and completion rides
## DayManager.day_started exactly the way farm.gd's crop growth does — no separate timer. A
## completed structure gets its kind's final BUILDING_COLORS fill; a completed storage structure
## (BuildingDB.is_storage) additionally becomes a working chest via the same chest_toggled
## signal/UI the layout chest already uses.

const Inventory := preload("res://scripts/inventory.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const BuildGrid := preload("res://scripts/build_grid.gd")
const FarmGrid := preload("res://scripts/farm_grid.gd")

signal chest_toggled(inventory: Inventory, cell: Vector2i)

const CELL_SIZE := 16

## Placeholder fill colors per building kind — locked GDD.md §9 settlement-anchor palette hexes,
## chosen so every kind reads as visually distinct at the 16px tile scale (see class doc / the
## Phase 4 report for the specific reasoning per kind).
const BUILDING_COLORS := {
	"farmhouse": "#7b5025",       # worn wood (dark) — derelict, weathered home
	"mayor_house": "#9d9180",     # scavenged metal — "concrete-patched walls," fortified
	"store": "#e1982a",           # dusty amber (identity color) — the economic heart
	"shack": "#b77c3e",           # worn wood (light) — patched-plank settler homes
	"chest": "#ffc948",           # lamplight gold — stands out as "loot/storage"
	"bulletin_board": "#ffedb1",  # worn cream — worn-paper notice board
	# Phase 4 Stage 2 player-buildable kinds (data/buildings.json):
	"shelter_tent": "#95ac49",    # faded field green — a salvaged-tarp lean-to
	"storage_shed": "#7d452a",    # rusted iron-brown — a scrap-sheet storage hut
}

## Under-construction fill for a placed blueprint: the GDD §9 rain-sky blue-grey at ~half alpha,
## because translucent blue is the universal "blueprint" read and no completed building uses it.
const BLUEPRINT_COLOR := Color("#7fa1b7", 0.55)

## One real second Inventory (ROADMAP.md Phase 4: "opens a second Inventory instance... giving
## the player extra storage") backing the farmland's storage chest. Reused verbatim from
## scripts/inventory.gd per the scope note; see this session's report for the documented
## limitation that item-transfer UX (drag/move-in) is deferred, not just display/toggle.
var chest_inventory: Inventory = Inventory.new()

var _test_map: Node2D
var _chest_cell: Vector2i = Vector2i(-1, -1)
var _bodies: Array[StaticBody2D] = []

## Runtime-placed structures (Phase 4 Stage 2). Each entry: {building_id, kind, top_left, size,
## placed_day, visual} — visual is the body's ColorRect, recolored in place on completion.
var _pending: Array[Dictionary] = []
var _completed: Array[Dictionary] = []
## Completed storage structures' own Inventory instances, keyed by top_left — one fresh instance
## per built Storage Shed, exactly the chest_inventory pattern generalized.
var _storage_inventories: Dictionary = {}


func _ready() -> void:
	_test_map = get_parent()
	for building in _test_map.layout.buildings():
		_spawn_building(building)
	# Construction completion rides the same once-per-day signal crop growth uses (see class doc).
	DayManager.day_started.connect(_on_day_started)


func _spawn_building(building: Dictionary) -> void:
	var top_left: Vector2i = building["top_left"]
	var footprint_size: Vector2i = building["size"]
	var kind := String(building["kind"])
	if kind == "chest":
		_chest_cell = top_left
	_spawn_footprint_body(top_left, footprint_size,
		Color(String(BUILDING_COLORS.get(kind, "#8c8478"))))


## The shared "one StaticBody2D + one flat-color ColorRect covering the footprint" spawner —
## Phase 4 Stage 1's layout-building pattern, factored out so Stage 2's runtime blueprints reuse
## it verbatim. Returns the ColorRect so completion can recolor it in place.
func _spawn_footprint_body(top_left: Vector2i, footprint_size: Vector2i, fill: Color) -> ColorRect:
	var px_size := Vector2(footprint_size) * float(CELL_SIZE)
	# _test_map is typed as the generic Node2D (see class doc — avoids a circular preload with
	# test_map.gd), so its cell_to_world_center() return type isn't statically known; an explicit
	# Vector2 annotation is needed here (`:=` can't infer through the untyped call).
	var center: Vector2 = _test_map.cell_to_world_center(top_left) \
		+ Vector2(footprint_size - Vector2i.ONE) * (float(CELL_SIZE) * 0.5)

	var body := StaticBody2D.new()
	body.collision_layer = 1  # "world" — see project.godot [layer_names]
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = px_size - Vector2(2, 2)  # 1px margin each side, matches farm.gd's resource props
	shape.shape = rect
	body.add_child(shape)

	var visual := ColorRect.new()
	visual.size = px_size - Vector2(2, 2)
	visual.position = -visual.size * 0.5
	visual.color = fill
	body.add_child(visual)

	add_child(body)
	_bodies.append(body)
	return visual


## -- Phase 4 Stage 2: runtime building placement --

## Whether a footprint can be constructed here. Per cell: inside the map, plain open grass only
## (FarmGrid's tillable-terrain rule — deliberately excludes authored farmland 'f', docks, gates,
## water, fence, and former tree/ore cells, whose ASCII chars persist after clearing), not
## layout-solid or inside any building footprint (test_map.is_blocked_at, which also covers
## already-placed/pending runtime buildings via the _runtime_blocked overlay), not player-tilled,
## and free of crops and standing tree/ore resource nodes.
func can_place(top_left: Vector2i, footprint_size: Vector2i) -> bool:
	if not BuildGrid.cells_within_map(top_left, footprint_size, _test_map.layout.size()):
		return false
	var farm: Node = _test_map.get_node("Farm")
	for cell in BuildGrid.footprint_cells(top_left, footprint_size):
		if _test_map.is_blocked_at(cell) or _test_map.is_tilled_at(cell):
			return false
		if not FarmGrid.is_tillable_terrain(String(_test_map.terrain_at(cell))):
			return false
		if not farm.get_plot(cell).is_empty():
			return false
		if farm.can_chop(cell) or farm.can_mine(cell):
			return false
	return true


## Place a structure blueprint: spawns the collidable under-construction body and registers its
## footprint in test_map's runtime-blocked overlay (so hoes and other blueprints can't target
## those cells while it builds). Resource/energy spending is the CALLER's job (scripts/
## builder.gd's confirm step) — this node stays inventory-agnostic, as it is for the layout chest.
func place_blueprint(building_id: String, top_left: Vector2i) -> bool:
	if not BuildingDB.has_building(building_id):
		return false
	var footprint_size := BuildingDB.size_of(building_id)
	if not can_place(top_left, footprint_size):
		return false
	var visual := _spawn_footprint_body(top_left, footprint_size, BLUEPRINT_COLOR)
	_pending.append({
		"building_id": building_id,
		"kind": BuildingDB.kind(building_id),
		"top_left": top_left,
		"size": footprint_size,
		"placed_day": DayManager.day,
		"visual": visual,
	})
	_test_map.block_cells(BuildGrid.footprint_cells(top_left, footprint_size))
	return true


func _on_day_started(day: int) -> void:
	var still_pending: Array[Dictionary] = []
	for entry in _pending:
		if BuildGrid.is_construction_complete(int(entry["placed_day"]), day,
				BuildingDB.build_days(String(entry["building_id"]))):
			_complete_construction(entry)
		else:
			still_pending.append(entry)
	_pending = still_pending


func _complete_construction(entry: Dictionary) -> void:
	var visual: ColorRect = entry["visual"]
	visual.color = Color(String(BUILDING_COLORS.get(String(entry["kind"]), "#8c8478")))
	_completed.append(entry)
	if BuildingDB.is_storage(String(entry["building_id"])):
		_storage_inventories[entry["top_left"]] = Inventory.new()


## The storage Inventory reachable at a cell: the layout chest's, or a completed storage
## structure's (any cell of its footprint counts, so a 2x2 shed is interactable from every side).
## null when the cell isn't storage.
func storage_inventory_at(cell: Vector2i) -> Inventory:
	if cell == _chest_cell:
		return chest_inventory
	for entry in _completed:
		var top_left: Vector2i = entry["top_left"]
		var footprint_size: Vector2i = entry["size"]
		if _storage_inventories.has(top_left) \
				and cell.x >= top_left.x and cell.x < top_left.x + footprint_size.x \
				and cell.y >= top_left.y and cell.y < top_left.y + footprint_size.y:
			return _storage_inventories[top_left]
	return null


func is_chest_at(cell: Vector2i) -> bool:
	return storage_inventory_at(cell) != null


## Called by player.gd when the player interacts (use_tool) facing a storage cell — the layout
## chest or a completed Storage Shed. Instant — no energy cost, no tool-swing lock, matching
## HUD's existing toggle_inventory ("I" key) UX rather than farming's tool-swing dispatch.
func interact_chest(cell: Vector2i) -> void:
	var inv := storage_inventory_at(cell)
	if inv != null:
		chest_toggled.emit(inv, cell)
