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

const Inventory := preload("res://scripts/inventory.gd")

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
}

## One real second Inventory (ROADMAP.md Phase 4: "opens a second Inventory instance... giving
## the player extra storage") backing the farmland's storage chest. Reused verbatim from
## scripts/inventory.gd per the scope note; see this session's report for the documented
## limitation that item-transfer UX (drag/move-in) is deferred, not just display/toggle.
var chest_inventory: Inventory = Inventory.new()

var _test_map: Node2D
var _chest_cell: Vector2i = Vector2i(-1, -1)
var _bodies: Array[StaticBody2D] = []


func _ready() -> void:
	_test_map = get_parent()
	for building in _test_map.layout.buildings():
		_spawn_building(building)


func _spawn_building(building: Dictionary) -> void:
	var top_left: Vector2i = building["top_left"]
	var footprint_size: Vector2i = building["size"]
	var kind := String(building["kind"])
	if kind == "chest":
		_chest_cell = top_left

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
	visual.color = Color(String(BUILDING_COLORS.get(kind, "#8c8478")))
	body.add_child(visual)

	add_child(body)
	_bodies.append(body)


func is_chest_at(cell: Vector2i) -> bool:
	return cell == _chest_cell


## Called by player.gd when the player interacts (use_tool) facing the chest cell. Instant — no
## energy cost, no tool-swing lock, matching HUD's existing toggle_inventory ("I" key) UX rather
## than farming's tool-swing dispatch.
func interact_chest() -> void:
	chest_toggled.emit(chest_inventory, _chest_cell)
