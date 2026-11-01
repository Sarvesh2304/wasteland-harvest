extends Node
## What each finished Town Works project changes in the world (Milestone B 2026-10-08,
## docs/SOCIAL_AND_QUESTS.md §6). main.gd calls apply() at boot (new game or load) and whenever a
## project is finished overnight; it's idempotent, re-deriving the town from the quests state.
##   - shop_expansion: Marta's store gets its bigger shopfront, and shipping pays 10% more.
##   - clinic: the ruined clinic is rebuilt and Doc's tent comes down; her clinic service opens
##     (heal, medical shelf: main.gd's clinic handlers, priced here).
##   - watchtower: a lit watchtower by the west gate; Kael can drive straight to any district
##     already reached (main.gd's ride-out prompt).
##   - greenhouse: the farm's old glasshouse is rebuilt and its plot grows anything, any season.

const GreenhouseScript := preload("res://scripts/greenhouse.gd")

const SHOP_SALE_MULTIPLIER := 1.1
const CLINIC_HEAL_PRICE := 80
const CLINIC_STOCK: Array[String] = ["bandage", "medkit", "purifier", "adrenal_shot"]
const WATCHTOWER_CELL := Vector2i(1, 1)
const WATCHTOWER_SIZE := Vector2i(2, 2)
## [colour, strength, radius scale, height above the base in px]: the lookout's lantern.
const WATCHTOWER_LIGHT := ["#ffc27a", 0.85, 1.1, 46]
const DOC_TENT_CELL := Vector2i(7, 13)
const DOC_TENT_SIZE := Vector2i(2, 2)

var zones: Dictionary = {}
var quests: Node = null
var greenhouse: Node2D = null


func setup(zone_dict: Dictionary, quests_node: Node) -> void:
	zones = zone_dict
	quests = quests_node


func apply() -> void:
	if quests == null or zones.is_empty():
		return
	var town: Node = zones["town"]["structures"]
	var shop: bool = quests.is_finished("shop_expansion")
	for zone_id in zones:
		zones[zone_id]["structures"].sale_multiplier = SHOP_SALE_MULTIPLIER if shop else 1.0
	if shop and town.building_kind("store") != "store_expanded":
		town.set_building_art("store", "store_expanded")
	if quests.is_finished("clinic"):
		if town.building_kind("clinic") != "town_clinic":
			town.set_building_art("clinic", "town_clinic")
		town.remove_works_building("doc_tent", DOC_TENT_CELL, DOC_TENT_SIZE)
	else:
		town.add_works_building("doc_tent", "doc_tent", DOC_TENT_CELL, DOC_TENT_SIZE)
	if quests.is_finished("watchtower"):
		town.add_works_building("watchtower", "watchtower", WATCHTOWER_CELL, WATCHTOWER_SIZE,
			WATCHTOWER_LIGHT)
	_apply_greenhouse()


func _apply_greenhouse() -> void:
	var restored: bool = quests.is_finished("greenhouse")
	if greenhouse != null:
		if greenhouse.restored != restored:
			greenhouse.set_restored(restored)
		return
	var farm_map: Node2D = zones["farm"]["map"]
	var layout = farm_map.get("layout")
	if layout == null or not layout.has_method("greenhouse_site"):
		return
	greenhouse = GreenhouseScript.new()
	greenhouse.name = "Greenhouse"
	greenhouse.y_sort_enabled = true
	farm_map.add_child(greenhouse)
	greenhouse.setup(farm_map, layout.greenhouse_site(), restored)


## The farm greenhouse's door cell (for tools and tests), or (-1, -1) before it's built.
func greenhouse_door() -> Vector2i:
	return GreenhouseScript.door_cell(greenhouse.top_left) if greenhouse != null else Vector2i(-1, -1)
