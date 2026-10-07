extends Node2D
## Decorative props layer: instantiates the active layout's decor_props() as static,
## NON-collidable Sprite2Ds. Two consumers today: the Ranch/Sanctuary's pen animals (MAPS.md
## §3 — the keeper's visible stock, so the ranch reads as alive and working before the player
## has bought anything) and, since the zone split, the Path corridor's dressing (the
## wrecked-car landmark + road weeds, see path_layout_standard.gd's design doc).
##
## Deliberately its OWN node (sibling to Structures/Npcs under TestMap), not a Structures child:
## these props have no collision body and no gameplay state, whereas Structures is exclusively
## collidable building volumes whose child count several tests assert against — mixing decor
## sprites in would perturb that count for no reason. Same data-driven "read a list off the active
## layout, spawn one node per entry" shape Structures uses for buildings() and Npcs for npcs().
##
## NO animal-entity system: these are pure scenery. Live, wandering, buyable livestock and the
## player's own Barn/Coop are Phase 8's job (GDD.md §8 "Animals & pets"); this layer only
## establishes the compound's atmosphere and the building shapes the player will later construct.
##
## Real PixelLab art at art/props/<kind>.png (view low top-down like the characters, so the
## animals read as recognizable critters rather than top-down blobs), with a flat-color placeholder
## fallback so the game still runs — and headless tests still pass — without the art present. Same
## fallback pattern as structures.gd's _building_texture() / farm.gd's _crop_texture().
##
## No save/load: like the NPCs (scripts/npcs.gd), these are cosmetic and simply respawn from the
## layout data on every map build.
##
## 2026-10-07: entries with an "art" key use the generated environment art (res://art/env/<art>.png)
## instead: the sprite stands on its footprint's bottom edge (y-sorted with the player, like the
## trees), "solid" props get a collision body and register their footprint as blocked (so NPCs,
## tilling and building placement all respect them), and "frames"/"fps" animate a horizontal
## strip (the wind turbine's blades, the fire pit's flames).

const CELL_SIZE := 16

## Flat-color fallback fills per prop kind (used only when the art PNG is absent) — dusty hide
## for the cow, a mutant grey-green for the goat, scavenged-metal rust for the Path zone's
## wrecked-car landmark, faded field green for its road weeds.
const PROP_COLORS := {
	"ranch_cow": "#c9b89a",
	"ranch_goat": "#8a9a7a",
	"wrecked_car": "#9d9180",
	"weed_tuft": "#95ac49",
}

const ENV_ART_DIR := "res://art/env/"

var _test_map: Node2D
var _props: Array[Sprite2D] = []
## Animated env props: [sprite, frames, fps] — advanced together from one clock.
var _animated: Array = []
## Props with a night frame (lamps): [sprite, night_frame].
var _night_props: Array = []
const DUSK_MINUTES := 18 * 60 + 30
const DAWN_MINUTES := 6 * 60
var _clock := 0.0
var _body: StaticBody2D = null


func _ready() -> void:
	_test_map = get_parent()
	y_sort_enabled = true
	for prop in _test_map.layout.decor_props():
		if prop.has("art"):
			_spawn_env_prop(prop)
		else:
			_spawn_prop(prop)
	set_process(not _animated.is_empty())
	if not _night_props.is_empty():
		DayManager.time_changed.connect(_on_time_changed)
		_on_time_changed(DayManager.day, DayManager.minutes_into_day)


func _on_time_changed(_day: int, minutes: float) -> void:
	var night := minutes >= DUSK_MINUTES or minutes < DAWN_MINUTES
	for entry in _night_props:
		(entry[0] as Sprite2D).frame = int(entry[1]) if night else 0


func _process(delta: float) -> void:
	_clock += delta
	for entry in _animated:
		var sprite: Sprite2D = entry[0]
		sprite.frame = int(_clock * float(entry[2])) % int(entry[1])


## A generated-art prop standing on its footprint (see class doc).
func _spawn_env_prop(prop: Dictionary) -> void:
	var cell: Vector2i = prop["cell"]
	var size: Vector2i = prop.get("size", Vector2i.ONE)
	var path := ENV_ART_DIR + String(prop["art"]) + ".png"
	var sprite := Sprite2D.new()
	var frames := maxi(int(prop.get("frames", 1)), 1)
	var w := float(CELL_SIZE)
	var h := float(CELL_SIZE)
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		sprite.texture = texture
		sprite.hframes = frames
		w = texture.get_width() / float(frames)
		h = texture.get_height()
	else:
		sprite.texture = _prop_texture(String(prop["kind"]))
	sprite.centered = false
	sprite.position = Vector2((cell.x + size.x / 2.0) * CELL_SIZE, (cell.y + size.y) * CELL_SIZE)
	sprite.offset = Vector2(-w / 2.0, -h)
	add_child(sprite)
	_props.append(sprite)
	if frames > 1 and float(prop.get("fps", 0)) > 0.0:
		_animated.append([sprite, frames, float(prop["fps"])])
	if prop.has("night_frame"):
		_night_props.append([sprite, int(prop["night_frame"])])
	if bool(prop.get("solid", false)):
		_block_footprint(cell, size)


func _block_footprint(cell: Vector2i, size: Vector2i) -> void:
	if _body == null:
		_body = StaticBody2D.new()
		_body.name = "PropCollision"
		_body.collision_layer = 1  # "world"
		_body.collision_mask = 0
		add_child(_body)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size) * CELL_SIZE
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = (Vector2(cell) + Vector2(size) / 2.0) * CELL_SIZE
	_body.add_child(col)
	var cells: Array[Vector2i] = []
	for dy in size.y:
		for dx in size.x:
			cells.append(cell + Vector2i(dx, dy))
	_test_map.block_cells(cells)


func _spawn_prop(prop: Dictionary) -> void:
	var kind := String(prop["kind"])
	var cell: Vector2i = prop["cell"]
	var sprite := Sprite2D.new()  # centered by default: the 32px art overhangs its 16px cell,
	# reading as an animal standing in the pasture (the CLAUDE.md sprite-beyond-tile convention)
	sprite.texture = _prop_texture(kind)
	sprite.position = _test_map.cell_to_world_center(cell)
	add_child(sprite)
	_props.append(sprite)


## Real art if the kind's file exists, else a flat-color placeholder ImageTexture.
func _prop_texture(kind: String) -> Texture2D:
	var path := "res://art/props/%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(String(PROP_COLORS.get(kind, "#8c8478"))))
	return ImageTexture.create_from_image(image)


## All spawned prop sprites (tests inspect these directly).
func props() -> Array[Sprite2D]:
	return _props
