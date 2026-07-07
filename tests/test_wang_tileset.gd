extends "res://tests/test_case.gd"
## Wang corner-mask → atlas-coordinate lookup (Phase 2). The strongest check here validates
## the entire lookup table against BOTH PixelLab .json metadata files shipped with the Phase 1
## sheets, so the table can never silently drift from the actual art.

const WangTileset := preload("res://scripts/wang_tileset.gd")

const METADATA_PATHS := [
	"res://art/tiles/settlement/grass_soil_tileset.json",
	"res://art/tiles/ruins/rubble_planks_tileset.json",
]


func test_uniform_tiles() -> void:
	assert_eq(WangTileset.atlas_for_corners(false, false, false, false), WangTileset.ALL_LOWER)
	assert_eq(WangTileset.atlas_for_corners(true, true, true, true), WangTileset.ALL_UPPER)


func test_single_corner_tiles() -> void:
	assert_eq(WangTileset.atlas_for_corners(true, false, false, false), Vector2i(1, 1), "NW only")
	assert_eq(WangTileset.atlas_for_corners(false, true, false, false), Vector2i(2, 0), "NE only")
	assert_eq(WangTileset.atlas_for_corners(false, false, true, false), Vector2i(2, 2), "SW only")
	assert_eq(WangTileset.atlas_for_corners(false, false, false, true), Vector2i(3, 1), "SE only")


func test_table_matches_pixellab_metadata() -> void:
	for path in METADATA_PATHS:
		var text := FileAccess.get_file_as_string(path)
		assert_true(text.length() > 0, "metadata readable: %s" % path)
		var data: Dictionary = JSON.parse_string(text)
		var tiles: Array = data["tileset_data"]["tiles"]
		assert_eq(tiles.size(), 16, "16 wang tiles in %s" % path)
		for tile in tiles:
			var corners: Dictionary = tile["corners"]
			var atlas := WangTileset.atlas_for_corners(
				corners["NW"] == "upper",
				corners["NE"] == "upper",
				corners["SW"] == "upper",
				corners["SE"] == "upper"
			)
			var bbox: Dictionary = tile["bounding_box"]
			var expected := Vector2i(int(bbox["x"]) / 16, int(bbox["y"]) / 16)
			assert_eq(atlas, expected, "%s in %s" % [tile["name"], path])


func test_all_sixteen_masks_map_to_distinct_tiles() -> void:
	var seen := {}
	for mask in 16:
		var atlas := WangTileset.atlas_for_corners(
			mask & 8 != 0, mask & 4 != 0, mask & 2 != 0, mask & 1 != 0)
		seen[atlas] = true
	assert_eq(seen.size(), 16, "every corner mask maps to a unique atlas tile")
