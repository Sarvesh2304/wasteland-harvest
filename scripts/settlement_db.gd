extends RefCounted
## Static data for the 3 starting settlements (ROADMAP.md Phase 4 / MAPS.md §1): id, display
## name, lore blurb, resource-lean label + starting-inventory bonus, and which map_layouts/*.gd
## script paints the world for that choice. scenes/settlement_select.tscn reads list() to build
## its 3 options; scripts/test_map.gd reads layout_for_id() to pick which layout to paint;
## scripts/main.gd reads starting_items() to grant the lean's starting-resource bonus once the
## player exists.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const SettlementDB := preload("res://scripts/settlement_db.gd")`.

const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")
# Zone-split layouts (the Farm/Path/Town/Ranch scene separation): the farm layouts above are
# farm-zone-only now; the Path/Town/Ranch zones each ship a standard variant (Open Plains +
# Forest Edge) and a riverside variant (river west column / bridge crossing). Dispatched by
# layout_for_zone() below.
const PathStandardLayout := preload("res://scripts/map_layouts/path_layout_standard.gd")
const PathRiversideLayout := preload("res://scripts/map_layouts/path_layout_riverside.gd")
const TownStandardLayout := preload("res://scripts/map_layouts/town_layout_standard.gd")
const TownRiversideLayout := preload("res://scripts/map_layouts/town_layout_riverside.gd")
const RanchStandardLayout := preload("res://scripts/map_layouts/ranch_layout_standard.gd")
const RanchRiversideLayout := preload("res://scripts/map_layouts/ranch_layout_riverside.gd")

## Default/fallback choice when no selection has been made yet (e.g. a headless test or smoke
## script that boots scenes/main.tscn directly without going through the selection screen first)
## — Open Plains, since it's the repurposed original test map and keeps those callers' existing
## assumptions about "a sensible default start" intact.
const DEFAULT_ID := "open_plains"

## Order here is the order the selection screen presents them in and the order hotbar_slot_1/2/3
## map to (see settlement_select.gd).
const SETTLEMENTS: Array[Dictionary] = [
	{
		"id": "open_plains",
		"name": "Open Plains",
		"resource_lean": "Better Soil",
		"lore": "The founders crested a rise and saw grass to the horizon — old cropland gone " +
			"wild, deep dark topsoil that the war had poisoned less than anyone dared hope. No " +
			"cover, no walls, nothing between them and the weather but distance. They settled " +
			"it anyway, because people who had spent twenty-five years hiding in ruins " +
			"understood exactly what they were looking at: land that would feed everyone they " +
			"had ever lost, if someone was brave enough to stand in the open and work it.",
		"summary": "The largest, cleanest farm plots of the three starts — highest yields, " +
			"but wood, stone, and scrap are all scarce on-map.",
		"layout_id": "open_plains",
		# Better soil lean: extra seed variety to put those big plots to work immediately.
		"starting_items": [
			{"item_id": "seed_dustwheat", "count": 5},
			{"item_id": "seed_sunbloom", "count": 5},
		],
	},
	{
		"id": "forest_edge",
		"name": "Forest Edge",
		"resource_lean": "Ruin Materials",
		"lore": "The founders followed a creek up out of the wastes and stopped where the " +
			"trees began. What looked like wild forest turned out to be younger than it " +
			"seemed: half a century of green swallowing a pre-war suburb. Under the moss " +
			"there are foundations; under the leaf-litter, street signs. The settlement grew " +
			"up in a broad clearing with its back to the woods — the founders liked that the " +
			"trees hid them from the road, and they liked even better that the forest was " +
			"full of the old world's bones, close enough to haul home by handcart.",
		"summary": "Scrap, concrete, and timber sit within walking distance from day one, but " +
			"farm plots are cramped and irregular with the weakest yields of the three.",
		"layout_id": "forest_edge",
		# Ruin materials lean: a building-materials head start.
		"starting_items": [
			{"item_id": "wood", "count": 15},
			{"item_id": "scrap_metal", "count": 8},
			{"item_id": "stone", "count": 8},
		],
	},
	{
		"id": "riverside",
		"name": "Riverside",
		"resource_lean": "Water Access",
		"lore": "The founders stopped at the river because everyone stops at the river. A " +
			"slow, wide bend with a gravel shallow, an intact pre-war bridge pier to anchor a " +
			"dock to, and water that ran clean enough once the filters were built. The " +
			"settlement grew along the bank the way river towns always have — and when the " +
			"first trade caravans started moving again, they moved along the water, which " +
			"means Riverside heard the news first and sold to the messengers.",
		"summary": "Naturally irrigated silt-row farmland and the best early trade access in " +
			"the game, but buildable land is a narrow ribbon and stone/scrap are scarcest here.",
		"layout_id": "riverside",
		# Water access lean: trade goods and food security instead of raw building materials
		# (no fishing/irrigation systems exist yet to grant directly — see report for this
		# judgment call).
		"starting_items": [
			{"item_id": "preserved_food", "count": 5},
			{"item_id": "bottle_caps", "count": 10},
		],
	},
]


static func list() -> Array[Dictionary]:
	return SETTLEMENTS


static func get_settlement(id: String) -> Dictionary:
	for s in SETTLEMENTS:
		if String(s.get("id", "")) == id:
			return s
	return {}


static func has_settlement(id: String) -> bool:
	return not get_settlement(id).is_empty()


## The map_layouts/*.gd script (a GDScript "class" reference — every member is a static func,
## called directly on this reference, e.g. `layout_for_id(id).spawn_cell()`) that paints the
## world for a given settlement id. Unknown ids fall back to the default layout rather than
## erroring, since scripts/test_map.gd calls this unconditionally at build time.
static func layout_for_id(id: String):
	match id:
		"forest_edge":
			return ForestEdgeLayout
		"riverside":
			return RiversideLayout
		_:
			return OpenPlainsLayout


## The layout script for one ZONE of a playthrough (the Farm/Path/Town/Ranch zone split):
## the farm zone still varies per settlement (layout_for_id above, now farm-only maps), while
## Path/Town/Ranch each come in a standard variant and a riverside variant — Riverside's river
## forms those zones' west edges (MAPS.md §1), so it's the one start that changes their terrain.
## Unknown zone ids fall back to the farm layout, mirroring layout_for_id's own
## unknown-id-tolerant contract (scripts/test_map.gd calls this unconditionally at build time).
static func layout_for_zone(zone_id: String, settlement_id: String):
	var riverside := settlement_id == "riverside"
	match zone_id:
		"path":
			return PathRiversideLayout if riverside else PathStandardLayout
		"town":
			return TownRiversideLayout if riverside else TownStandardLayout
		"ranch":
			return RanchRiversideLayout if riverside else RanchStandardLayout
		_:
			return layout_for_id(settlement_id)


static func starting_items(id: String) -> Array[Dictionary]:
	var s := get_settlement(id)
	if s.is_empty():
		return []
	var items: Array[Dictionary] = []
	for entry in s.get("starting_items", []):
		items.append(entry)
	return items
