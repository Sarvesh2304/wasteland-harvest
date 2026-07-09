extends "res://tests/test_case.gd"
## Phase 5 Stage 1 wander-zone math (scripts/npc_grid.gd) — the pure core behind npc.gd's
## "wanders within a defined zone" checklist item. See npc_grid.gd's class doc for why this is a
## validated grid random-walk rather than NavigationAgent2D.

const NpcGrid := preload("res://scripts/npc_grid.gd")


func test_within_zone_true_at_center_and_edges() -> void:
	var home := Vector2i(10, 10)
	assert_true(NpcGrid.within_zone(home, home, 2), "home cell is always inside its own zone")
	assert_true(NpcGrid.within_zone(Vector2i(12, 10), home, 2), "east edge (radius 2) is inside")
	assert_true(NpcGrid.within_zone(Vector2i(8, 12), home, 2), "corner (radius 2,2) is inside")


func test_within_zone_false_outside_radius() -> void:
	var home := Vector2i(10, 10)
	assert_false(NpcGrid.within_zone(Vector2i(13, 10), home, 2), "one cell past the east edge")
	assert_false(NpcGrid.within_zone(Vector2i(10, 7), home, 2), "one cell past the north edge")


func test_candidate_steps_only_returns_open_in_zone_neighbours() -> void:
	var home := Vector2i(5, 5)
	var current := Vector2i(5, 5)
	var blocked := {Vector2i(6, 5): true}  # east neighbour blocked
	var is_open := func(cell: Vector2i) -> bool: return not blocked.has(cell)
	var candidates := NpcGrid.candidate_steps(current, home, 2, is_open)
	assert_eq(candidates.size(), 3, "3 of the 4 cardinal neighbours are open")
	assert_false(Vector2i(6, 5) in candidates, "blocked neighbour excluded")
	assert_true(Vector2i(4, 5) in candidates, "open west neighbour included")
	assert_true(Vector2i(5, 4) in candidates, "open north neighbour included")
	assert_true(Vector2i(5, 6) in candidates, "open south neighbour included")


func test_candidate_steps_excludes_neighbours_outside_zone() -> void:
	# Standing at the zone's east edge (radius 1 from home): the east neighbour would leave the
	# zone even though it's physically open, so it must not be offered as a candidate.
	var home := Vector2i(5, 5)
	var current := Vector2i(6, 5)
	var is_open := func(_cell: Vector2i) -> bool: return true
	var candidates := NpcGrid.candidate_steps(current, home, 1, is_open)
	assert_false(Vector2i(7, 5) in candidates, "stepping further east would leave the wander zone")
	assert_true(Vector2i(6, 4) in candidates, "north stays within the zone")
	assert_true(Vector2i(6, 6) in candidates, "south stays within the zone")
	assert_true(Vector2i(5, 5) in candidates, "stepping back toward home stays within the zone")


func test_candidate_steps_empty_when_boxed_in() -> void:
	var home := Vector2i(5, 5)
	var is_open := func(_cell: Vector2i) -> bool: return false
	var candidates := NpcGrid.candidate_steps(home, home, 2, is_open)
	assert_true(candidates.is_empty(), "no open neighbours -> no candidate steps")


func test_candidate_steps_empty_when_radius_zero() -> void:
	# A 0-radius zone means the NPC is pinned to its home cell — every neighbour is "outside the
	# zone" even if physically open.
	var home := Vector2i(5, 5)
	var is_open := func(_cell: Vector2i) -> bool: return true
	var candidates := NpcGrid.candidate_steps(home, home, 0, is_open)
	assert_true(candidates.is_empty(), "radius 0 leaves no legal step")
