extends Node2D
## The farm greenhouse (Milestone B 2026-10-08, the "greenhouse" Town Works project —
## docs/SOCIAL_AND_QUESTS.md §6). It stands on every farm from day one as the player's late
## parents' old glasshouse, frame rusted and panes gone; the project rebuilds it, after which crops
## inside grow in any season.
##
## A walled garden with no roof (so the crops show from above): an 8x6 footprint whose outer ring
## is wall, with a one-cell door in the south wall, leaving a 6x4 plot inside. Each farm layout
## names its site (greenhouse_site()). The walls are separate sprites so they depth-sort against
## the player properly: the north wall and south wall each sort at their own row, and the side walls
## are cut into one slice per row. Collision rects cover the wall cells, and the map's runtime
## overlay marks them blocked (tools, NPCs, spawns). farm.gd's greenhouse_cells holds the interior
## once it's restored.

const SIZE := Vector2i(8, 6)
const DOOR_X := 3
const CELL := 16
const ART := "res://art/buildings/greenhouse_%s%s.png"

var top_left := Vector2i.ZERO
var restored := false
var _map: Node2D = null
var _sprites: Array[Sprite2D] = []
var _body: StaticBody2D = null


## The ring of wall cells (door excluded) for a greenhouse at `origin`.
static func wall_cells(origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in SIZE.y:
		for x in SIZE.x:
			var edge := y == 0 or y == SIZE.y - 1 or x == 0 or x == SIZE.x - 1
			if edge and not (y == SIZE.y - 1 and x == DOOR_X):
				out.append(origin + Vector2i(x, y))
	return out


## The 6x4 plot inside.
static func interior_cells(origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(1, SIZE.y - 1):
		for x in range(1, SIZE.x - 1):
			out.append(origin + Vector2i(x, y))
	return out


static func door_cell(origin: Vector2i) -> Vector2i:
	return origin + Vector2i(DOOR_X, SIZE.y - 1)


## Builds it on `map` (a test_map.gd) at `origin`: clears natural clutter off the wall cells (never a
## player's placed chest or machine), blocks them, and draws it ruined or restored.
func setup(map: Node2D, origin: Vector2i, is_restored: bool) -> void:
	_map = map
	top_left = origin
	var objects: Node = map.get_node_or_null("Objects")
	var farm: Node = map.get_node_or_null("Farm")
	for cell in wall_cells(origin):
		if objects != null and objects.has_object(cell):
			var anchor: Vector2i = objects.anchor_of(cell)
			if not WorldObjectDB.is_placed(String(objects.kind_at(cell))):
				objects.remove(anchor)
		if farm != null and farm.has_method("clear_plot_at"):
			farm.clear_plot_at(cell)
	map.block_cells(wall_cells(origin))
	_build_collision()
	_build_sprites()
	set_restored(is_restored)


func set_restored(value: bool) -> void:
	restored = value
	var suffix := "" if restored else "_ruined"
	for sprite in _sprites:
		var piece := String(sprite.get_meta("piece"))
		var path := ART % [piece, suffix]
		if not ResourceLoader.exists(path):
			path = ART % [piece, ""]
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else _placeholder(piece)
		var region: Rect2 = sprite.get_meta("region", Rect2())
		sprite.texture = tex
		if region.size != Vector2.ZERO:
			sprite.region_enabled = true
			sprite.region_rect = region
			sprite.offset = Vector2(0, -region.size.y / 2.0)
		else:
			sprite.offset = Vector2(0, -float(tex.get_height()) / 2.0)
		# Without its own ruined art the restored art stands in, aged.
		var aged := not restored and not ResourceLoader.exists(ART % [piece, "_ruined"])
		sprite.modulate = Color(0.62, 0.55, 0.48, 0.85) if aged else Color.WHITE
	var farm: Node = _map.get_node_or_null("Farm") if _map != null else null
	if farm != null and "greenhouse_cells" in farm:
		var cells := {}
		if restored:
			for cell in interior_cells(top_left):
				cells[cell] = true
		farm.greenhouse_cells = cells


## -- Drawing --

## Local position of the bottom-centre of a run of cells (x0..x1 on row y).
func _base(x0: int, x1: int, y: int) -> Vector2:
	var cx := (float(top_left.x + x0) + float(top_left.x + x1 + 1)) * CELL / 2.0
	return Vector2(cx, float(top_left.y + y + 1) * CELL)


func _build_sprites() -> void:
	_add_piece("back", _base(0, SIZE.x - 1, 0))
	_add_piece("front", _base(0, SIZE.x - 1, SIZE.y - 1))
	# Each side wall in per-row slices of the 16x64 strip, so each slice sorts on its own row.
	for row in range(1, SIZE.y - 1):
		var region := Rect2(0, (row - 1) * CELL, CELL, CELL)
		_add_piece("side", _base(0, 0, row), region, false)
		_add_piece("side", _base(SIZE.x - 1, SIZE.x - 1, row), region, true)


func _add_piece(piece: String, at: Vector2, region: Rect2 = Rect2(), flip: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.set_meta("piece", piece)
	sprite.set_meta("region", region)
	sprite.position = at
	sprite.flip_h = flip
	add_child(sprite)
	_sprites.append(sprite)


func _build_collision() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	var runs := [
		[0, SIZE.x - 1, 0, 0],                         # north wall
		[0, 0, 1, SIZE.y - 2],                         # west
		[SIZE.x - 1, SIZE.x - 1, 1, SIZE.y - 2],       # east
		[0, DOOR_X - 1, SIZE.y - 1, SIZE.y - 1],       # south, left of the door
		[DOOR_X + 1, SIZE.x - 1, SIZE.y - 1, SIZE.y - 1],  # south, right of the door
	]
	for r in runs:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var w := (int(r[1]) - int(r[0]) + 1) * CELL
		var h := (int(r[3]) - int(r[2]) + 1) * CELL
		rect.size = Vector2(w - 2, h - 2)
		shape.shape = rect
		shape.position = Vector2(float(top_left.x + int(r[0])) * CELL + w / 2.0,
			float(top_left.y + int(r[2])) * CELL + h / 2.0)
		_body.add_child(shape)


## A plain stand-in if the art is missing (frame grey, glass blue).
static func _placeholder(piece: String) -> Texture2D:
	var size := Vector2i(128, 32) if piece == "back" else (Vector2i(128, 24) if piece == "front" else Vector2i(16, 64))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.78, 0.8, 0.45))
	for x in size.x:
		img.set_pixel(x, size.y - 1, Color("#5b5146"))
		img.set_pixel(x, 0, Color("#5b5146"))
	return ImageTexture.create_from_image(img)


const WorldObjectDB := preload("res://scripts/world_object_db.gd")
