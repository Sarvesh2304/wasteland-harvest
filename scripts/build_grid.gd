extends RefCounted
## Pure building-placement logic (ROADMAP.md Phase 4 Stage 2 "Basic building placement... simple
## grid-snap system"): footprint anchoring/enumeration, map-bounds math, cost affordability, and
## construction-day-completion math. No scene/node state lives here — scripts/builder.gd and
## scripts/structures.gd own the stateful nodes and call into these static functions, exactly the
## farm_grid.gd / inventory.gd convention of keeping rules pure and headlessly unit-testable
## (tests/test_build_grid.gd) separate from the nodes that apply them.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const BuildGrid := preload("res://scripts/build_grid.gd")`.

## Grid-snap anchoring rule: the placement target is the single cell directly ahead of the player
## (player.gd's established _target_cell() convention), and a multi-cell footprint always extends
## AWAY from the player from that cell — so the target cell is the footprint's nearest edge, and
## the player can never end up standing inside the collision body they just placed. Facing south
## or east the target is already the top-left corner; facing north or west the top-left shifts
## back by the footprint's extent so the rectangle grows upward/leftward instead of into the
## player.
static func anchored_top_left(target_cell: Vector2i, size: Vector2i, facing: String) -> Vector2i:
	match facing:
		"north":
			return target_cell - Vector2i(0, size.y - 1)
		"west":
			return target_cell - Vector2i(size.x - 1, 0)
		_:
			return target_cell


## Every logical cell a footprint covers, row-major from top_left.
static func footprint_cells(top_left: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(top_left + Vector2i(x, y))
	return cells


## True if the whole footprint sits inside the map's logical cell grid. Needed as an explicit
## check because layout_common.gd's cell() deliberately reads out-of-bounds cells as plain grass
## (a dual-grid rendering convenience) — without this, a footprint could hang off the map edge
## and still pass every terrain test.
static func cells_within_map(top_left: Vector2i, size: Vector2i, map_size: Vector2i) -> bool:
	return top_left.x >= 0 and top_left.y >= 0 \
		and top_left.x + size.x <= map_size.x and top_left.y + size.y <= map_size.y


## True if `have` ({item_id: owned count}) covers every line of `cost` ({item_id: needed count}).
static func can_afford(have: Dictionary, cost: Dictionary) -> bool:
	for item_id in cost:
		if int(have.get(item_id, 0)) < int(cost[item_id]):
			return false
	return true


## The checklist's "wait 1 in-game day", as pure day math: a blueprint placed on day N completes
## on the first day_started tick where the day counter has advanced by build_days (so build_days
## = 1 means "done next morning", whether that morning arrives by natural midnight rollover or by
## DayManager.skip_to_next_morning() — both paths emit the same signal, see day_manager.gd).
static func is_construction_complete(placed_day: int, current_day: int, build_days: int) -> bool:
	return current_day >= placed_day + build_days


## Wrap-around catalog cycling — same math as settlement_select.gd's wrap_index (duplicated
## rather than preloading a whole Control scene script just for two lines of posmod).
static func wrap_index(current: int, delta: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(current + delta, count)
