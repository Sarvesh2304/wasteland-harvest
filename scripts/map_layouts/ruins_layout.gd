extends RefCounted
## The ruins zone's layout (Milestone C, 2026-10-07): an INSTANCE wrapping one generated level
## (scripts/ruins_gen.gd's output), answering the same calls the settlement zones' static layout
## scripts answer (size/cell/is_solid/spawn_cell/...), so scripts/test_map.gd renders a ruins
## level exactly like any other zone. Objects, enemies, containers and rad sources are not part
## of the layout: main.gd's expedition flow spawns them from the level dictionary.
##
## Row legend (ruins_gen.gd): '.' ash ground, 'a' asphalt, 'c' concrete, 'r' rubble-strewn
## ground, ':' dirt (all walkable); 'F' ruined wall, '#' rubble heap, 'X' under a building,
## 'W' flooded water (all solid). Off the map counts as solid.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16
const SOLID_CHARS: Array[String] = ["F", "#", "X", "W"]

var rows: Array[String] = []
var level: Dictionary = {}


func _init(level_data: Dictionary = {}) -> void:
	level = level_data
	var src = level_data.get("rows", [])
	for r in src:
		rows.append(String(r))
	if rows.is_empty():
		rows = placeholder_rows()


## A small walled concrete yard: what the ruins map holds before any expedition has run.
static func placeholder_rows() -> Array[String]:
	var out: Array[String] = []
	for y in 12:
		if y == 0 or y == 11:
			out.append("F".repeat(20))
		else:
			out.append("F" + "c".repeat(18) + "F")
	return out


func size() -> Vector2i:
	return LayoutCommon.size(rows)


func cell(x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "F"
	return rows[y][x]


func is_solid(x: int, y: int) -> bool:
	return SOLID_CHARS.has(cell(x, y))


func is_soil(_x: int, _y: int) -> bool:
	return false


func is_tree(_x: int, _y: int) -> bool:
	return false


func is_ore(_x: int, _y: int) -> bool:
	return false


func is_tillable(_x: int, _y: int) -> bool:
	return false


func spawn_cell() -> Vector2i:
	return level.get("entry", Vector2i(2, 2))


func resource_node_cells() -> Array[Dictionary]:
	return []


func buildings() -> Array[Dictionary]:
	return []


func building_at(_x: int, _y: int) -> Dictionary:
	return {}


func npcs() -> Array[Dictionary]:
	return []


func decor_props() -> Array[Dictionary]:
	return []


func zone_exits() -> Array[Dictionary]:
	return []


func water_cells() -> Array[Vector2i]:
	return _cells_with("W")


func fence_cells() -> Array[Vector2i]:
	return _cells_with("F")


func dock_cells() -> Array[Vector2i]:
	return []


func gate_cells() -> Array[Vector2i]:
	return []


func farm_gap_cells() -> Array[Vector2i]:
	return []


func map_rect() -> Rect2:
	return LayoutCommon.map_rect(rows, CELL_SIZE)


func cell_center(cell_coords: Vector2i) -> Vector2:
	return LayoutCommon.cell_center(cell_coords, CELL_SIZE)


func _cells_with(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == ch:
				out.append(Vector2i(x, y))
	return out
