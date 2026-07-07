extends RefCounted
## Corner-terrain → atlas-coordinate lookup for the Phase 1 PixelLab "tileset15" Wang sheets.
##
## Both Phase 1 sheets (art/tiles/settlement/grass_soil_tileset.png and
## art/tiles/ruins/rubble_planks_tileset.png) use PixelLab's tileset15 4x4 layout, and their
## .json metadata places every wang tile at identical atlas positions — verified against both
## files — so a single lookup table serves both. Each sheet blends two terrains, "lower" and
## "upper"; a tile's identity is its four corners' terrains, encoded as the bitmask
## NW*8 + NE*4 + SW*2 + SE*1 (upper = 1). PixelLab's wang_N tile names ARE that bitmask,
## which is what makes this table straightforward to derive from the metadata.
##
## Used by the test map's dual-grid ground painter (scripts/test_map.gd) instead of Godot's
## editor-authored terrain sets, so map painting stays fully scriptable and headlessly testable.

## Index = corner bitmask (NW*8 + NE*4 + SW*2 + SE*1), value = atlas coords in the 4x4 sheet.
const ATLAS_BY_CORNER_MASK: Array[Vector2i] = [
	Vector2i(2, 1),  # 0b0000 all lower
	Vector2i(3, 1),  # 0b0001 SE upper
	Vector2i(2, 2),  # 0b0010 SW upper
	Vector2i(1, 2),  # 0b0011 S edge upper
	Vector2i(2, 0),  # 0b0100 NE upper
	Vector2i(3, 2),  # 0b0101 E edge upper
	Vector2i(0, 1),  # 0b0110 NE+SW diagonal
	Vector2i(3, 3),  # 0b0111 all but NW
	Vector2i(1, 1),  # 0b1000 NW upper
	Vector2i(2, 3),  # 0b1001 NW+SE diagonal
	Vector2i(1, 0),  # 0b1010 W edge upper
	Vector2i(0, 2),  # 0b1011 all but NE
	Vector2i(3, 0),  # 0b1100 N edge upper
	Vector2i(0, 0),  # 0b1101 all but SW
	Vector2i(1, 3),  # 0b1110 all but SE
	Vector2i(0, 3),  # 0b1111 all upper
]

## Convenience aliases for the two uniform tiles.
const ALL_LOWER := Vector2i(2, 1)
const ALL_UPPER := Vector2i(0, 3)


## true = that corner is the sheet's "upper" terrain (soil in the settlement sheet, planks in
## the ruins sheet); false = "lower" (grass / rubble respectively).
static func atlas_for_corners(nw: bool, ne: bool, sw: bool, se: bool) -> Vector2i:
	var mask := (8 if nw else 0) | (4 if ne else 0) | (2 if sw else 0) | (1 if se else 0)
	return ATLAS_BY_CORNER_MASK[mask]
