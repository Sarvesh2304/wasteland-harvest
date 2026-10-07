extends RefCounted
## Pure ground-painting rules for the 2026-10-07 terrain renderer (scripts/terrain_tiles.gd builds
## the TileSets, scripts/test_map.gd paints with them). Static-only so the painting decisions are
## unit-testable without a scene.
##
## Layers, bottom to top: seasonal grass base (logical grid), then dual-grid overlays (road, rubble
## ground, tilled soil, wet soil, water), plank decking, decor (flowers/tufts), and y-sorted
## scenery sprites (fences, rubble piles). See docs/ART_STYLE.md §4 for the sheet contracts.
##
## Dual grid: a visual tile sits on the corner shared by four logical cells, so visual tile
## (vx, vy) samples logical cells (vx-1, vy-1) NW, (vx, vy-1) NE, (vx-1, vy) SW and (vx, vy) SE.
## Its mask m = NW*8 + NE*4 + SW*2 + SE*1 picks the tile at column m % 4, row m / 4 of a 64x64
## overlay sheet; m == 15 uses one of the sheet's four "_full" variants instead.

const NW := 8
const NE := 4
const SW := 2
const SE := 1
const FULL := 15

## Fence connection bits (art/env/fences/*.png: 16x32 frames, mask at column m % 4, row m / 4).
const FENCE_N := 1
const FENCE_E := 2
const FENCE_S := 4
const FENCE_W := 8

const NEIGHBOURS_8: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

## Grass base variants (8 per season): plain ones most of the time, the ones with a pebble or a
## sprout now and then.
const GRASS_VARIANT_WEIGHTS: Array[int] = [10, 10, 3, 10, 10, 4, 10, 3]


static func corner_mask(nw: bool, ne: bool, sw: bool, se: bool) -> int:
	return (NW if nw else 0) | (NE if ne else 0) | (SW if sw else 0) | (SE if se else 0)


## Atlas coords of `mask` in a 4x4 overlay sheet.
static func overlay_atlas(mask: int) -> Vector2i:
	return Vector2i(mask % 4, mask / 4)


## The mask of the visual tile at `visual` for a terrain whose logical cells are `is_in`.
static func visual_mask(visual: Vector2i, is_in: Callable) -> int:
	return corner_mask(
		bool(is_in.call(visual + Vector2i(-1, -1))),
		bool(is_in.call(visual + Vector2i(0, -1))),
		bool(is_in.call(visual + Vector2i(-1, 0))),
		bool(is_in.call(visual)))


## The four visual tiles whose corners touch logical `cell` (what to repaint when it changes).
static func visuals_touching(cell: Vector2i) -> Array[Vector2i]:
	return [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]


static func fence_mask(n: bool, e: bool, s: bool, w: bool) -> int:
	return (FENCE_N if n else 0) | (FENCE_E if e else 0) | (FENCE_S if s else 0) | (FENCE_W if w else 0)


## Pixel rect of a fence connection frame in its 64x128 sheet.
static func fence_region(mask: int) -> Rect2i:
	return Rect2i((mask % 4) * 16, (mask / 4) * 32, 16, 32)


## Deterministic per-cell pick in [0, count).
static func variant(cell: Vector2i, salt: int, count: int) -> int:
	if count <= 1:
		return 0
	return absi(hash([cell.x, cell.y, salt])) % count


## Deterministic weighted pick: index into `weights`.
static func weighted_variant(cell: Vector2i, salt: int, weights: Array[int]) -> int:
	var total := 0
	for w in weights:
		total += w
	var roll := variant(cell, salt, maxi(total, 1))
	for i in weights.size():
		roll -= weights[i]
		if roll < 0:
			return i
	return 0


## Decor sprite name ("" = none) for a grass cell: scattered flowers, tufts and specks, and a thick
## layer of tufts on old fields so they read as rough, overgrown ground.
static func decor_for(cell: Vector2i, season: String, old_field: bool) -> String:
	var roll := variant(cell, 7, 1000)
	if old_field:
		if roll < 520:
			return "tuft_%s_%d" % [season, 1 + variant(cell, 8, 3)]
		if roll < 600:
			return "flowers_%s_%d" % [season, 1 + variant(cell, 9, 4)]
		return ""
	if roll < 35:
		return "flowers_%s_%d" % [season, 1 + variant(cell, 9, 4)]
	if roll < 95:
		return "tuft_%s_%d" % [season, 1 + variant(cell, 8, 3)]
	if roll < 130:
		return "specks_%d" % (1 + variant(cell, 10, 2))
	if season == "autumn" and roll < 190:
		return "leaves_autumn_%d" % (1 + variant(cell, 11, 2))
	return ""


## The 'p' (plank/pavement) cells of a layout split by what they are: 4-connected components of 'p'
## that touch water ('W', diagonals included) are wooden decking (docks, footbridges, river-gate
## landings), everything else is old road. Returns
## {"planks": {cell: "v"|"h"}, "road": {cell: true}, "bridge": {cell: true}} where "v"/"h" is the
## board direction (boards run across the walkway) and "bridge" marks plank cells spanning water,
## which the water layer flows under.
static func classify_planks(layout) -> Dictionary:
	var size: Vector2i = layout.size()
	var seen := {}
	var planks := {}
	var road := {}
	var bridge := {}
	for y in size.y:
		for x in size.x:
			var start := Vector2i(x, y)
			if seen.has(start) or String(layout.cell(x, y)) != "p":
				continue
			var component: Array[Vector2i] = []
			var touches_water := false
			var lo := start
			var hi := start
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				component.append(c)
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				for d in NEIGHBOURS_8:
					var n: Vector2i = c + d
					var ch := String(layout.cell(n.x, n.y))
					if ch == "W":
						touches_water = true  # diagonals count: a landing at a river gate
					elif ch == "p" and not seen.has(n) and (d.x == 0 or d.y == 0):
						seen[n] = true
						stack.append(n)
			if not touches_water:
				for c in component:
					road[c] = true
				continue
			# Boards run across the walkway: an east-west run gets north-south boards ("v").
			var dir := "v" if (hi.x - lo.x) >= (hi.y - lo.y) else "h"
			for c in component:
				planks[c] = dir
				var w := func(o: Vector2i) -> bool: return String(layout.cell(o.x, o.y)) == "W"
				if (w.call(c + Vector2i.UP) and w.call(c + Vector2i.DOWN)) \
						or (w.call(c + Vector2i.LEFT) and w.call(c + Vector2i.RIGHT)):
					bridge[c] = true
	return {"planks": planks, "road": road, "bridge": bridge}
