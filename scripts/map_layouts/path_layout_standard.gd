extends RefCounted
## The Path zone, STANDARD variant (Open Plains + Forest Edge starts) — the new interstitial
## corridor between Farm (west) and Town (east), added by the Farm/Path/Town/Ranch zone split.
## Structural idea from Stardew's Farm→Bus Stop→Town connection (conceptual reference ONLY, per
## docs/STARDEW_REFERENCE.md's IP-safety framing), themed for this world as a ruined,
## weed-overgrown road: connective tissue, not a destination.
##
## Content (24x12 cells — a bit wider than the 20x12 viewport so it scrolls, short in the
## walking direction since it is pure connective tissue):
##   - The main WALKABLE corridor is the open dirt band at rows 4-5, running unbroken from the
##     west gate to the east gate — always open, nothing here ever blocks the Day-1 town loop.
##   - A ruined pre-war paved road runs PARALLEL to it (rows 6-7, 'p' — the ruins tileset's
##     plank/pavement tile reads as broken paving at 16px, zero new tile art needed), with
##     overgrown weeds decorating its cracks (weed_tuft props, see decor_props()) — the
##     established "reclaimed by nature" visual language.
##   - The wrecked-car landmark (decor_props(), art/props/wrecked_car.png) sits ON the dead
##     road near mid-corridor, off the walkable dirt line — reusing Forest Edge's existing
##     "rusted car half-eaten" lore image (a vehicle, reclaimed by weeds) as this zone's
##     "the world before" statement.
##   - A separate, LOCKED checkpoint gate structure on the NORTH side (row 1: 'F' posts at
##     x9/x14 flanking a '#' rubble-sealed gateway at x10-13, with a plank spur at x11-12
##     branching north off the road toward it): the settlement's sealed backup gate, physically
##     impassable ('#' and 'F' both collide). Visual only — NO zone_exits() entry, NO unlock
##     logic — matching the Ranch's "structure now, system later" precedent. Its future unlock
##     (combat-readiness gated, leading to wider open-world content) is deliberately unscoped
##     here; this is the "glimpse" half of the plan's glimpse-vs-panorama fortification split
##     with the deferred Town↔Ranch transition zone.
##   - Safe zone like Farm/Town (GDD.md §4): vigilance, not danger — the corridor is kept clear.
##
## No farmland, no buildings, no NPCs (a checkpoint guard is a natural future touch, not now).
##
## The riverside variant (path_layout_riverside.gd) differs only near its east end, where the
## river that forms Riverside's western town wall crosses the corridor (plank bridge at the
## walk rows) — literal duplication with this cross-reference comment, matching the farm layout
## files' own convention.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFFFFFFFF",
	"F........F####F........F",
	"F..........pp..........F",
	"F..........pp..........F",
	"G..........pp..........G",
	"G..........pp..........G",
	"F.pppppppppppppppppppp.F",
	"F.pppppppppppppppppppp.F",
	"F......................F",
	"F......................F",
	"F......................F",
	"FFFFFFFFFFFFFFFFFFFFFFFF",
]

const BUILDINGS: Array[Dictionary] = []


## Zone transitions (see test_map.gd's zone_exit_at / main.gd's _on_zone_exit_requested):
##   - west gate → Farm's east-wall gate-break landing. That entry cell is a FARM-LOCAL literal
##     picked by hand to sit just inside the farm's east gate — it is not derived from the farm's
##     geometry, so it has to move whenever the farm's gate does. It moved from (34, 4) to
##     (70, 15) with the 2026-08-09 72x32 farm expansion (see open_plains_layout.gd's class doc);
##     verified open, non-gate ground in all 3 farm layouts;
##   - east gate → Town's west-wall gate-break landing (town-local (1, 4)).
## The sealed checkpoint gateway (row 1) is deliberately NOT an exit — see the class doc.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(0, 4), Vector2i(0, 5)], "target_zone": "farm",
			"entry_cell": Vector2i(70, 15)},
		{"gate_cells": [Vector2i(23, 4), Vector2i(23, 5)], "target_zone": "town",
			"entry_cell": Vector2i(1, 4)},
	]


static func size() -> Vector2i:
	return LayoutCommon.size(ROWS)


static func cell(x: int, y: int) -> String:
	return LayoutCommon.cell(ROWS, x, y)


static func is_soil(x: int, y: int) -> bool:
	return LayoutCommon.is_soil(ROWS, x, y)


static func is_tree(x: int, y: int) -> bool:
	return LayoutCommon.is_tree(ROWS, x, y)


static func is_ore(x: int, y: int) -> bool:
	return LayoutCommon.is_ore(ROWS, x, y)


static func is_solid(x: int, y: int) -> bool:
	return LayoutCommon.is_solid(ROWS, BUILDINGS, x, y)


static func is_tillable(x: int, y: int) -> bool:
	return LayoutCommon.is_tillable(ROWS, BUILDINGS, x, y)


static func spawn_cell() -> Vector2i:
	return LayoutCommon.spawn_cell(ROWS)


static func resource_node_cells() -> Array[Dictionary]:
	return LayoutCommon.resource_node_cells(ROWS)


static func buildings() -> Array[Dictionary]:
	return BUILDINGS


static func npcs() -> Array[Dictionary]:
	return []


## The zone's dressing (scripts/props.gd, same static non-collidable pattern as the ranch
## animals): the wrecked-car landmark on the dead road, plus weed tufts in its cracks and one
## sprouting at the sealed checkpoint's foot. Art at art/props/<kind>.png with flat-color
## fallback (see art/props/README.md).
static func decor_props() -> Array[Dictionary]:
	return [
		{"kind": "wrecked_car", "cell": Vector2i(7, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(3, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(5, 7)},
		{"kind": "weed_tuft", "cell": Vector2i(10, 7)},
		{"kind": "weed_tuft", "cell": Vector2i(14, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(17, 7)},
		{"kind": "weed_tuft", "cell": Vector2i(20, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(12, 2)},
	]


static func building_at(x: int, y: int) -> Dictionary:
	return LayoutCommon.building_at(BUILDINGS, x, y)


static func water_cells() -> Array[Vector2i]:
	return LayoutCommon.water_cells(ROWS)


static func fence_cells() -> Array[Vector2i]:
	return LayoutCommon.fence_cells(ROWS)


static func dock_cells() -> Array[Vector2i]:
	return LayoutCommon.dock_cells(ROWS)


static func gate_cells() -> Array[Vector2i]:
	return LayoutCommon.gate_cells(ROWS)


static func farm_gap_cells() -> Array[Vector2i]:
	return LayoutCommon.farm_gap_cells(ROWS)


static func map_rect() -> Rect2:
	return LayoutCommon.map_rect(ROWS, CELL_SIZE)


static func cell_center(cell_coords: Vector2i) -> Vector2:
	return LayoutCommon.cell_center(cell_coords, CELL_SIZE)
