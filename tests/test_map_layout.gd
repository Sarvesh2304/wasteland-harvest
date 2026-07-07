extends "res://tests/test_case.gd"
## Phase 2 test-map layout data integrity (scripts/test_map_layout.gd): well-formed grid,
## sealed border, valid spawn, and world-space math the camera and player spawn rely on.

const TestMapLayout := preload("res://scripts/test_map_layout.gd")

const LEGAL_CHARS := [".", "f", "p", "#", "@"]


func test_grid_is_rectangular() -> void:
	var width: int = TestMapLayout.ROWS[0].length()
	for y in TestMapLayout.ROWS.size():
		assert_eq(TestMapLayout.ROWS[y].length(), width, "row %d width" % y)


func test_only_legal_characters() -> void:
	for y in TestMapLayout.ROWS.size():
		var row: String = TestMapLayout.ROWS[y]
		for x in row.length():
			assert_true(row[x] in LEGAL_CHARS, "cell (%d,%d) is '%s'" % [x, y, row[x]])


func test_border_is_sealed() -> void:
	# The player must not be able to walk off the map: the outer ring is all solid rubble.
	var size := TestMapLayout.size()
	for x in size.x:
		assert_true(TestMapLayout.is_solid(x, 0), "top border at x=%d" % x)
		assert_true(TestMapLayout.is_solid(x, size.y - 1), "bottom border at x=%d" % x)
	for y in size.y:
		assert_true(TestMapLayout.is_solid(0, y), "left border at y=%d" % y)
		assert_true(TestMapLayout.is_solid(size.x - 1, y), "right border at y=%d" % y)


func test_exactly_one_spawn_on_walkable_ground() -> void:
	var count := 0
	for y in TestMapLayout.ROWS.size():
		for x in TestMapLayout.ROWS[y].length():
			if TestMapLayout.cell(x, y) == "@":
				count += 1
	assert_eq(count, 1, "exactly one '@' spawn marker")
	var spawn := TestMapLayout.spawn_cell()
	assert_false(TestMapLayout.is_solid(spawn.x, spawn.y), "spawn is not inside rubble")


func test_has_farmland_and_variety() -> void:
	# ROADMAP Phase 2 asks for "farmland + surrounding area": soil, planks, and interior
	# rubble must all exist.
	var found := {"f": 0, "p": 0, "#": 0}
	var size := TestMapLayout.size()
	for y in range(1, size.y - 1):  # interior only, so '#' isn't just the border
		for x in range(1, size.x - 1):
			var ch := TestMapLayout.cell(x, y)
			if found.has(ch):
				found[ch] += 1
	assert_true(found["f"] > 0, "farmland soil exists")
	assert_true(found["p"] > 0, "plank floor exists")
	assert_true(found["#"] > 0, "interior rubble obstacles exist")


func test_out_of_bounds_reads_as_grass() -> void:
	assert_eq(TestMapLayout.cell(-1, -1), ".", "dual-grid sampling beyond edges sees grass")
	assert_eq(TestMapLayout.cell(9999, 3), ".")


func test_world_space_math() -> void:
	var size := TestMapLayout.size()
	assert_eq(TestMapLayout.map_rect(), Rect2(0, 0, size.x * 16, size.y * 16))
	assert_eq(TestMapLayout.cell_center(Vector2i(0, 0)), Vector2(8, 8), "cell centers at half-tile")
	var spawn_pos := TestMapLayout.cell_center(TestMapLayout.spawn_cell())
	assert_true(TestMapLayout.map_rect().has_point(spawn_pos), "spawn position inside map bounds")
