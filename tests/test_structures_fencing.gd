extends "res://tests/test_case.gd"
## Phase 8 Stage 2 (fencing & perimeter system): scripts/structures.gd's new solid-collision
## plumbing (_spawn_footprint_body's `solid` param) and the can_place() occupied-footprint guard
## the unblocked-Gate gap needs (_is_footprint_occupied). Unlike every other file in this suite
## (headless pure-function checks over plain Dictionaries/Arrays), this one instantiates the
## real Structures node directly against a minimal fake test-map/farm stand-in — no scene file,
## no SceneTree add_child, just enough of the duck-typed interface structures.gd actually calls
## on its parent (cell_to_world_center/world_to_cell/is_blocked_at/is_tilled_at/terrain_at/
## block_cells/unblock_cells/layout, plus a "Farm" child exposing get_plot/can_chop/can_mine) for
## can_place()/place_blueprint()/_complete_construction() to run for real, unmodified. The
## player-actually-walks-through-it proof is tools/runtime_smoke.gd's job (its Phase 8 Stage 2
## addition) — this file covers the two things a live playthrough can't pin down as cleanly: the
## exact collision-shape presence/absence on the spawned body, and the occupied-footprint guard
## in isolation from movement/physics.
##
## GDScript has no real "private" — externally poking a script's underscore-prefixed members
## (_test_map, _spawn_footprint_body, _is_footprint_occupied, _complete_construction, _pending,
## _completed) is already this codebase's own convention (see tools/runtime_smoke.gd/soak_test.gd
## reading structures._pending/_completed directly), so this file does the same rather than
## inventing new public test-only surface on structures.gd.

const StructuresScript := preload("res://scripts/structures.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const BuildGrid := preload("res://scripts/build_grid.gd")

const CELL_SIZE := 16


## Minimal fake layout: an open, unbounded plain-grass map (nothing layout-solid) — just enough
## for BuildGrid.cells_within_map()/is_blocked_at() to behave for any footprint this file places.
class FakeLayout:
	var _size: Vector2i

	func _init(map_size: Vector2i) -> void:
		_size = map_size

	func size() -> Vector2i:
		return _size

	func is_solid(_x: int, _y: int) -> bool:
		return false


## Minimal fake Farm sibling: no plots, no resource nodes — can_place() only asks it whether a
## cell holds a crop/tree/ore, and this stand-in always says "none," so every cell this file
## targets is placeable except where a structure's own footprint says otherwise.
class FakeFarm:
	extends Node

	func get_plot(_cell: Vector2i) -> Dictionary:
		return {}

	func can_chop(_cell: Vector2i) -> bool:
		return false

	func can_mine(_cell: Vector2i) -> bool:
		return false


## Minimal fake TestMap: implements exactly the duck-typed surface scripts/structures.gd calls
## on `_test_map` (that file's class doc: `_test_map` is typed as the generic Node2D specifically
## so any object with this shape works). Cells are pixel-perfect at CELL_SIZE=16, matching the
## real test_map.gd/structures.gd convention.
class FakeTestMap:
	extends Node2D

	var layout: FakeLayout
	var _blocked: Dictionary = {}
	var _tilled: Dictionary = {}

	func _init(map_size: Vector2i) -> void:
		layout = FakeLayout.new(map_size)
		var farm := FakeFarm.new()
		farm.name = "Farm"
		add_child(farm)

	func cell_to_world_center(cell: Vector2i) -> Vector2:
		return Vector2(cell) * float(CELL_SIZE) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5

	func world_to_cell(world_pos: Vector2) -> Vector2i:
		return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.y / CELL_SIZE)))

	func terrain_at(_cell: Vector2i) -> String:
		return "."  # plain tillable grass (FarmGrid.is_tillable_terrain)

	func is_blocked_at(cell: Vector2i) -> bool:
		return layout.is_solid(cell.x, cell.y) or _blocked.has(cell)

	func is_tilled_at(cell: Vector2i) -> bool:
		return _tilled.get(cell, false)

	func block_cells(cells: Array[Vector2i]) -> void:
		for cell in cells:
			_blocked[cell] = true

	func unblock_cells(cells: Array[Vector2i]) -> void:
		for cell in cells:
			_blocked.erase(cell)


## Fresh Structures node wired to a fresh fake map, bypassing _ready() entirely (which would
## expect a real layout.buildings() list and the live DayManager autoload) — every test here
## drives place_blueprint()/_complete_construction()/can_place() directly instead.
func _make_structures(map_size: Vector2i = Vector2i(50, 50)) -> Dictionary:
	var structures := StructuresScript.new()
	var fake_map := FakeTestMap.new(map_size)
	structures._test_map = fake_map
	return {"structures": structures, "map": fake_map}


func _collision_shape_count(body: Node) -> int:
	var count := 0
	for child in body.get_children():
		if child is CollisionShape2D:
			count += 1
	return count


func _free_env(env: Dictionary) -> void:
	(env["structures"] as Node).free()
	(env["map"] as Node).free()


## -- _spawn_footprint_body's `solid` param, in isolation --

func test_spawn_footprint_body_adds_collision_shape_by_default() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	var visual: CanvasItem = structures._spawn_footprint_body(Vector2i(2, 2), Vector2i.ONE, "fence")
	var body := visual.get_parent()
	assert_eq(_collision_shape_count(body), 1, "solid defaults to true: one CollisionShape2D")
	_free_env(env)


func test_spawn_footprint_body_adds_collision_shape_when_explicitly_solid() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	var visual: CanvasItem = structures._spawn_footprint_body(
		Vector2i(2, 2), Vector2i.ONE, "fence", false, true)
	var body := visual.get_parent()
	assert_eq(_collision_shape_count(body), 1, "solid=true: one CollisionShape2D")
	_free_env(env)


func test_spawn_footprint_body_skips_collision_shape_when_not_solid() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	var visual: CanvasItem = structures._spawn_footprint_body(
		Vector2i(3, 3), Vector2i.ONE, "gate", false, false)
	var body := visual.get_parent()
	assert_eq(_collision_shape_count(body), 0, "solid=false: no CollisionShape2D at all")
	# The visual itself still exists (a Gate still renders, it just doesn't collide).
	assert_true(is_instance_valid(visual), "the visual node is still spawned")
	_free_env(env)


## -- _is_footprint_occupied(), in isolation --

func test_is_footprint_occupied_true_inside_a_completed_footprint() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	structures._completed.append({
		"building_id": "gate_wood", "kind": "gate",
		"top_left": Vector2i(5, 5), "size": Vector2i.ONE, "placed_day": 1,
	})
	assert_true(structures._is_footprint_occupied(Vector2i(5, 5)),
		"a completed structure's own cell reads as occupied")
	assert_false(structures._is_footprint_occupied(Vector2i(6, 5)),
		"a neighboring cell outside the footprint reads as unoccupied")
	_free_env(env)


func test_is_footprint_occupied_true_inside_a_pending_footprint() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	structures._pending.append({
		"building_id": "fence_wood", "kind": "fence",
		"top_left": Vector2i(8, 8), "size": Vector2i.ONE, "placed_day": 1,
	})
	assert_true(structures._is_footprint_occupied(Vector2i(8, 8)),
		"a pending structure's own cell reads as occupied too")
	_free_env(env)


## -- End-to-end through the real place_blueprint()/_complete_construction() flow --

func test_completed_gate_drops_collision_and_unblocks_but_stays_occupied() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	var fake_map = env["map"]
	var cell := Vector2i(10, 10)
	assert_true(structures.place_blueprint("gate_wood", cell), "gate blueprint placed")
	assert_true(fake_map.is_blocked_at(cell), "a construction site blocks like anything else")
	# _complete_construction() is called directly (bypassing the day-tick timer) — the pending
	# entry is what BuildGrid.is_construction_complete()/_on_day_started would hand it.
	structures._complete_construction(structures._pending[0])
	assert_eq(structures._completed.size(), 1, "the gate is now completed")
	var body: Node = structures._completed[0]["visual"].get_parent()
	assert_eq(_collision_shape_count(body), 0,
		"a completed non-solid Gate has no CollisionShape2D")
	assert_false(fake_map.is_blocked_at(cell),
		"test_map.unblock_cells() lifted the Gate's cell back out of the overlay")
	# The gap this opens, and the guard that closes it:
	assert_true(structures._is_footprint_occupied(cell),
		"the completed Gate still occupies its own footprint even though it's unblocked")
	assert_false(structures.can_place(cell, Vector2i.ONE),
		"can_place() refuses to rebuild on top of a completed, unblocked Gate")
	_free_env(env)


func test_completed_fence_keeps_collision_and_stays_blocked() -> void:
	var env := _make_structures()
	var structures = env["structures"]
	var fake_map = env["map"]
	var cell := Vector2i(12, 12)
	assert_true(structures.place_blueprint("fence_wood", cell), "fence blueprint placed")
	structures._complete_construction(structures._pending[0])
	var body: Node = structures._completed[0]["visual"].get_parent()
	assert_eq(_collision_shape_count(body), 1, "a completed solid Fence keeps its CollisionShape2D")
	assert_true(fake_map.is_blocked_at(cell), "a completed solid Fence stays in the blocked overlay")
	assert_false(structures.can_place(cell, Vector2i.ONE),
		"can_place() refuses to rebuild on a completed Fence (blocked AND occupied)")
	_free_env(env)


func test_only_the_gate_is_non_solid_among_the_new_fence_gate_entries() -> void:
	assert_true(BuildingDB.solid("fence_wood"))
	assert_true(BuildingDB.solid("fence_chainlink"))
	assert_true(BuildingDB.solid("fence_concrete"))
	assert_false(BuildingDB.solid("gate_wood"))
