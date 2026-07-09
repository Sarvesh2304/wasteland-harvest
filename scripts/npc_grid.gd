extends RefCounted
## Pure wander-zone math for Phase 5's NPCs (scripts/npc.gd) — the "wanders within a defined
## zone" checklist item's rules as static functions on plain data, headless-testable with no
## Node/scene required (tests/test_npc_grid.gd). Same pure-core/stateful-shell split as
## farm_grid.gd vs farm.gd.
##
## ## Judgment call: grid random-walk, NOT NavigationAgent2D (documented per the team model)
##
## ROADMAP.md's checklist parenthetical suggests NavigationAgent2D, but this codebase has never
## used Godot's navigation system anywhere: no NavigationRegion2D exists in any scene, and every
## piece of existing movement/placement logic (player facing-cell interaction, tilling, building
## placement) is plain grid math against test_map.gd's world_to_cell()/is_blocked_at(). What
## Phase 5 Stage 1 actually needs is "three NPCs amble a little near their homes" — a full baked
## navmesh (plus keeping it in sync with runtime-placed Phase 4 buildings, which would need
## re-baking or carve-outs every time the player builds something) is a lot of machinery for
## that, and navmesh pathing can cut corners through cells the grid considers blocked.
##
## Instead: an NPC idles a few seconds, then steps ONE cell in a random cardinal direction,
## where candidate cells must be (a) within a Chebyshev-distance wander_radius of the NPC's home
## cell and (b) not blocked (test_map.is_blocked_at — which already covers terrain solids,
## layout-building footprints, AND player-placed structures, so NPCs respect new construction
## for free, no re-bake). Because every step is validated before it starts and runs between two
## adjacent open cell centers, an NPC can never clip through terrain or leave its zone by
## construction. Revisit real navigation in Phase 7 if schedules need cross-town pathing.

## The wander zone is the square of cells within `radius` of `home` on both axes (Chebyshev
## distance) — matches how a "stands around near the mayor's house" zone reads on the grid.
static func within_zone(cell: Vector2i, home: Vector2i, radius: int) -> bool:
	return absi(cell.x - home.x) <= radius and absi(cell.y - home.y) <= radius


## The four cardinal neighbours of `current` that are inside the zone and pass `is_open`
## (a Callable(Vector2i) -> bool; the NPC node passes `not test_map.is_blocked_at(...)`).
## Returns [] when the NPC is boxed in — the caller just idles and retries later.
static func candidate_steps(current: Vector2i, home: Vector2i, radius: int,
		is_open: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for offset in offsets:
		var cell: Vector2i = current + offset
		if within_zone(cell, home, radius) and bool(is_open.call(cell)):
			out.append(cell)
	return out
