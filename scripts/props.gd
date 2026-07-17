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

var _test_map: Node2D
var _props: Array[Sprite2D] = []


func _ready() -> void:
	_test_map = get_parent()
	for prop in _test_map.layout.decor_props():
		_spawn_prop(prop)


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
