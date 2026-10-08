extends RefCounted
## Ruined-city level generator (Milestone C, 2026-10-08). Pure and deterministic: the same depth and
## seed always give the same level, from a local RandomNumberGenerator only. scripts/expedition.gd
## calls `load("res://scripts/ruins_gen.gd").generate(depth, seed)`; tests/test_ruins_gen.gd checks
## every rule below for many seeds.
##
## ## How a level is built
##   1. A street grid. Streets are 5 cells wide (sidewalk, three asphalt lanes, sidewalk) and
##      split the map into city blocks of about 12x12. The map edge is a crumbling wall, with
##      rubble where a street runs into it.
##   2. Kael's truck parks at the west end of a horizontal street; the player arrives just south of
##      it. The subway stairs go into the block farthest from the truck, on the sidewalk side.
##   3. Every block takes a role, weighted by district:
##        - a row of buildings facing the street below, with a back yard behind;
##        - a roofless ruin: brick walls, doorways, loot inside;
##        - a parking lot;
##        - a rubble field;
##        - a raider camp;
##        - a plaza;
##        - an industrial yard.
##   4. Streets get wrecks, a bus downtown, lamps, cones and barricades (chokepoints, never full
##      blocks), plus decor and the odd rad puddle deeper in.
##   5. Enemies spawn last, at least ENEMY_MIN_STEPS from the truck: packs, groups, solos.
##   6. A final reachability pass from the entry drops anything the player couldn't reach. Every
##      searchable thing keeps an open side, and the stairs' approach is always reachable.
##
## ## Output (generate()'s dictionary)
##   depth, theme, name, size (cells), rows (Array[String] of the legend below), wall_style (the
##   fence sheet the ruin walls use), entry (arrival cell, directly south of the truck's middle),
##   truck (3x1 anchor), stairs (2x2 anchor; walk up to stairs + (0, 2) to use them), and lists:
##     buildings [{kind, anchor, size}], props [{kind, anchor}], decor [{kind, cell}],
##     containers [{kind, anchor, tier}], breakables [{kind, anchor}],
##     enemies [{type, cell, group}] (group = pack id, -1 solo),
##     rad [{kind, anchor, strength}] (rads/sec at the centre), notes [Vector2i].
##   Footprints run right and down from the anchor.
## Row legend:
##   walkable: '.' ruins ground, 'a' asphalt, 'c' concrete, 'r' rubble ground, ':' dirt;
##   solid: 'F' low ruined wall, '#' rubble heap, 'X' building footprint (exactly the buildings'
##   cells), 'W' flooded water.

const THEMES: Array[String] = ["residential", "downtown", "industrial", "core"]
const NAMES: Array[String] = ["Residential Blocks", "Downtown Ruins", "Industrial Quarter", "The Core"]
const SIZES: Array[Vector2i] = [Vector2i(48, 32), Vector2i(56, 40), Vector2i(64, 48), Vector2i(64, 48)]
const WALL_STYLE := {"residential": "ruin_wall_brick", "downtown": "ruin_wall_brick",
	"industrial": "ruin_wall_concrete", "core": "ruin_wall_concrete"}
const STREET_W := 5
const SOLID_CHARS := "F#XW"
const WALKABLE_CHARS := ".acr:"

## Content per depth (index = min(depth, 4) - 1).
const ENEMY_COUNT: Array[Vector2i] = [Vector2i(6, 9), Vector2i(9, 13), Vector2i(12, 16), Vector2i(14, 18)]
const ENEMY_MIX: Array[Dictionary] = [
	{"shambler": 70, "runner": 30},
	{"shambler": 45, "runner": 25, "bloater": 15, "raider": 15},
	{"shambler": 30, "runner": 20, "bloater": 15, "raider": 15, "rad_hound": 20},
	{"shambler": 25, "runner": 20, "bloater": 15, "raider": 20, "rad_hound": 20},
]
const RAD_COUNT: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 3), Vector2i(3, 6), Vector2i(4, 8)]
## Searchable containers a level should offer at least (topped up across the blocks).
const CONTAINER_QUOTA: Array[int] = [6, 8, 10, 12]
const QUOTA_KINDS := {"residential": ["dumpster", "fridge", "locker", "car_trunk"],
	"downtown": ["dumpster", "locker", "filing_cabinet", "supply_crate"],
	"industrial": ["locker", "supply_crate", "dumpster", "car_trunk"],
	"core": ["supply_crate", "locker", "filing_cabinet", "dumpster"]}
const ENEMY_MIN_STEPS := 12
const TIER_BUMP_CHANCE := 0.15
## Block roles and their weights per district.
const BLOCK_WEIGHTS := {
	"residential": {"buildings": 50, "ruin": 20, "lot": 12, "rubble": 10, "plaza": 3, "yard": 5},
	"downtown": {"buildings": 50, "ruin": 16, "lot": 8, "rubble": 8, "plaza": 8, "camp": 10},
	"industrial": {"buildings": 30, "ruin": 15, "lot": 15, "rubble": 12, "yard": 20, "camp": 8},
	"core": {"buildings": 35, "ruin": 20, "lot": 8, "rubble": 15, "yard": 10, "camp": 8, "plaza": 4},
}
## At least this many blocks become building rows when the streets allow (a city needs facades).
const MIN_BUILDING_BLOCKS := 2
const BUILDINGS_BY_THEME := {
	"residential": ["ruin_house", "ruin_house", "ruin_garage", "ruin_shopfront"],
	"downtown": ["ruin_shopfront", "ruin_office", "ruin_apartment", "ruin_shopfront"],
	"industrial": ["ruin_garage", "ruin_garage", "ruin_office", "ruin_apartment"],
	"core": ["ruin_office", "ruin_apartment", "ruin_shopfront", "ruin_garage"],
}
const BUILDING_SIZE := {"ruin_shopfront": Vector2i(4, 2), "ruin_house": Vector2i(4, 2),
	"ruin_garage": Vector2i(4, 2), "ruin_office": Vector2i(5, 3), "ruin_apartment": Vector2i(6, 3)}
## Rows a building's sprite rises above its footprint (nothing else may sit there).
const BUILDING_OVERHANG := {"ruin_shopfront": 2, "ruin_house": 2, "ruin_garage": 1, "ruin_office": 4,
	"ruin_apartment": 3}
const PROP_SIZE := {"car_wreck_1": Vector2i(3, 1), "car_wreck_2": Vector2i(3, 1), "car_burnt": Vector2i(3, 1),
	"bus_wreck": Vector2i(6, 2), "barricade": Vector2i(2, 1), "concrete_barrier": Vector2i(2, 1),
	"streetlamp_broken": Vector2i(1, 1), "tire_pile": Vector2i(1, 1), "shopping_cart": Vector2i(1, 1),
	"oil_drum": Vector2i(1, 1), "traffic_cone": Vector2i(1, 1)}
## Breakables are 1x1 except the big scrap heap (data/world_objects.json sizes).
const BREAKABLE_SIZE := {"scrap_large": Vector2i(2, 2)}
const CONTAINER_SIZE := {"locker": Vector2i(1, 1), "fridge": Vector2i(1, 1), "supply_crate": Vector2i(1, 1),
	"filing_cabinet": Vector2i(1, 1), "dumpster": Vector2i(2, 1), "car_trunk": Vector2i(3, 1)}
const RUIN_LOOT := {"residential": ["fridge", "locker", "filing_cabinet"],
	"downtown": ["filing_cabinet", "locker", "fridge"],
	"industrial": ["locker", "supply_crate", "filing_cabinet"],
	"core": ["supply_crate", "filing_cabinet", "locker"]}
const CARS: Array[String] = ["car_wreck_1", "car_wreck_2", "car_burnt"]


## -- Public --

static func generate(depth: int, seed_value: int) -> Dictionary:
	var g := _Gen.new(maxi(depth, 1), seed_value)
	return g.run()


static func depth_index(depth: int) -> int:
	return clampi(depth, 1, 4) - 1


static func theme_for_depth(depth: int) -> String:
	return THEMES[depth_index(depth)]


static func name_for_depth(depth: int) -> String:
	return NAMES[depth_index(depth)]


static func is_walkable_char(ch: String) -> bool:
	return ch.length() == 1 and WALKABLE_CHARS.contains(ch)


static func building_overhang(kind: String) -> int:
	return int(BUILDING_OVERHANG.get(kind, 2))


## Cells covered by solid objects in `level` (buildings, props, containers, breakables, rad
## barrels, truck, stairs) -> true.
static func solid_footprints(level: Dictionary) -> Dictionary:
	var out := {}
	var add := func(anchor: Vector2i, size: Vector2i) -> void:
		for dy in size.y:
			for dx in size.x:
				out[anchor + Vector2i(dx, dy)] = true
	add.call(Vector2i(level["truck"]), Vector2i(3, 1))
	add.call(Vector2i(level["stairs"]), Vector2i(2, 2))
	for b in level["buildings"]:
		add.call(Vector2i(b["anchor"]), Vector2i(b["size"]))
	for p in level["props"]:
		add.call(Vector2i(p["anchor"]), PROP_SIZE.get(String(p["kind"]), Vector2i.ONE))
	for c in level["containers"]:
		add.call(Vector2i(c["anchor"]), CONTAINER_SIZE.get(String(c["kind"]), Vector2i.ONE))
	for b in level["breakables"]:
		add.call(Vector2i(b["anchor"]), BREAKABLE_SIZE.get(String(b["kind"]), Vector2i.ONE))
	for r in level["rad"]:
		if String(r["kind"]) == "rad_barrel":
			add.call(Vector2i(r["anchor"]), Vector2i.ONE)
	return out


## BFS step counts from `from` over walkable, unobstructed cells (-1 = unreachable), keyed by cell.
static func distances(level: Dictionary, from: Vector2i) -> Dictionary:
	var rows: Array = level["rows"]
	var size: Vector2i = level["size"]
	var solid := solid_footprints(level)
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y or dist.has(n):
				continue
			if not is_walkable_char(String(rows[n.y])[n.x]) or solid.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


## -- The generator --

class _Gen:
	var depth := 1
	var theme := "residential"
	var size := Vector2i.ZERO
	var rng := RandomNumberGenerator.new()
	var cells := PackedByteArray()  # row legend chars as bytes
	var used := PackedByteArray()   # 1 = an object (solid or flat) already occupies the cell
	var solid := PackedByteArray()  # 1 = a solid object stands here
	var h_streets: Array[int] = []  # top row of each horizontal street band
	var v_streets: Array[int] = []  # left column of each vertical street band
	var blocks: Array[Rect2i] = []
	var out := {}
	var _group := 0

	func _init(level_depth: int, seed_value: int) -> void:
		depth = level_depth
		theme = THEMES[clampi(depth, 1, 4) - 1]
		size = SIZES[clampi(depth, 1, 4) - 1]
		rng.seed = hash([seed_value, depth, "ruins"])
		cells.resize(size.x * size.y)
		cells.fill(46)  # '.'
		used.resize(size.x * size.y)
		used.fill(0)
		solid.resize(size.x * size.y)
		solid.fill(0)
		out = {"depth": depth, "theme": theme, "name": NAMES[clampi(depth, 1, 4) - 1], "size": size,
			"wall_style": WALL_STYLE[theme], "buildings": [], "props": [], "decor": [],
			"containers": [], "breakables": [], "enemies": [], "rad": [], "notes": []}

	# -- cell helpers --

	func inb(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y

	func idx(c: Vector2i) -> int:
		return c.y * size.x + c.x

	func ch(c: Vector2i) -> String:
		return "F" if not inb(c) else char(cells[idx(c)])

	func set_ch(c: Vector2i, s: String) -> void:
		if inb(c):
			cells[idx(c)] = s.unicode_at(0)

	func walkable(c: Vector2i) -> bool:
		return inb(c) and WALKABLE_CHARS.contains(ch(c)) and solid[idx(c)] == 0

	func free_rect(anchor: Vector2i, sz: Vector2i) -> bool:
		for dy in sz.y:
			for dx in sz.x:
				var c := anchor + Vector2i(dx, dy)
				if not inb(c) or not WALKABLE_CHARS.contains(ch(c)) or used[idx(c)] != 0:
					return false
		return true

	## Free rect with a walkable ring all round (so a solid thing here can't wall anything off).
	func open_rect(anchor: Vector2i, sz: Vector2i) -> bool:
		if not free_rect(anchor, sz):
			return false
		for dy in range(-1, sz.y + 1):
			for dx in range(-1, sz.x + 1):
				if dx >= 0 and dx < sz.x and dy >= 0 and dy < sz.y:
					continue
				var c := anchor + Vector2i(dx, dy)
				if not walkable(c):
					return false
		return true

	func mark(anchor: Vector2i, sz: Vector2i, is_solid: bool) -> void:
		for dy in sz.y:
			for dx in sz.x:
				var c := anchor + Vector2i(dx, dy)
				if inb(c):
					used[idx(c)] = 1
					if is_solid:
						solid[idx(c)] = 1

	func fill(r: Rect2i, s: String) -> void:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				set_ch(Vector2i(x, y), s)

	func pick_weighted(weights: Dictionary) -> String:
		var total := 0
		for k in weights:
			total += int(weights[k])
		var roll := rng.randi_range(0, maxi(total - 1, 0))
		for k in weights:
			roll -= int(weights[k])
			if roll < 0:
				return String(k)
		return String(weights.keys()[0])

	func rand_cell_in(r: Rect2i) -> Vector2i:
		return Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))

	func tier() -> int:
		var t := clampi(depth, 1, 3)
		if rng.randf() < TIER_BUMP_CHANCE:
			t += 1
		return mini(t, 4)

	# -- the build --

	func run() -> Dictionary:
		_lay_streets()
		_cut_blocks()
		_place_entry()
		var stairs_block := _place_stairs()
		# Guarantee a couple of building rows: pick them first, among blocks fronting a street.
		var eligible: Array[int] = []
		for i in blocks.size():
			if i != stairs_block and _street_below(blocks[i]) and blocks[i].size.y >= 7:
				eligible.append(i)
		var forced := {}
		while forced.size() < MIN_BUILDING_BLOCKS and not eligible.is_empty():
			var pick: int = eligible.pop_at(rng.randi_range(0, eligible.size() - 1))
			forced[pick] = true
		for i in blocks.size():
			if forced.has(i):
				_block_buildings(blocks[i])
			else:
				_dress_block(blocks[i], i == stairs_block)
		_dress_streets()
		_fill_containers()
		_ground_blobs()
		_place_rad()
		_scatter_decor()
		_place_enemies()
		_validate()
		var rows: Array[String] = []
		for y in size.y:
			var line := ""
			for x in size.x:
				line += char(cells[y * size.x + x])
			rows.append(line)
		out["rows"] = rows
		return out

	## Street bands across the map, evenly spaced with a little jitter.
	func _lay_streets() -> void:
		var nv := 2 if size.x <= 56 else 3
		var nh := 1 if size.y <= 32 else 2
		var span_x := float(size.x - 2) / float(nv + 1)
		for i in nv:
			var x := 1 + roundi(span_x * (i + 1)) - STREET_W / 2 + rng.randi_range(-1, 1)
			v_streets.append(x)
		var span_y := float(size.y - 2) / float(nh + 1)
		for i in nh:
			var y := 1 + roundi(span_y * (i + 1)) - STREET_W / 2 + rng.randi_range(-1, 1)
			h_streets.append(y)
		# Border: a crumbling wall all round.
		for x in size.x:
			set_ch(Vector2i(x, 0), "F")
			set_ch(Vector2i(x, size.y - 1), "F")
		for y in size.y:
			set_ch(Vector2i(0, y), "F")
			set_ch(Vector2i(size.x - 1, y), "F")
		for y0 in h_streets:
			_paint_street(Rect2i(1, y0, size.x - 2, STREET_W), true)
			set_ch(Vector2i(size.x - 1, y0 + 2), "#")  # streets run into rubble at the edge
		for x0 in v_streets:
			_paint_street(Rect2i(x0, 1, STREET_W, size.y - 2), false)
			set_ch(Vector2i(x0 + 2, 0), "#")
			set_ch(Vector2i(x0 + 2, size.y - 1), "#")

	func _paint_street(r: Rect2i, horizontal: bool) -> void:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var edge := (y == r.position.y or y == r.end.y - 1) if horizontal \
					else (x == r.position.x or x == r.end.x - 1)
				var c := Vector2i(x, y)
				# Crossings stay asphalt; sidewalks only where nothing else paved first.
				if edge:
					if ch(c) != "a":
						set_ch(c, "c")
				else:
					set_ch(c, "a")

	## The rectangles between the streets and the border.
	func _cut_blocks() -> void:
		var xs: Array[int] = [1]
		for x0 in v_streets:
			xs.append(x0)
			xs.append(x0 + STREET_W)
		xs.append(size.x - 1)
		var ys: Array[int] = [1]
		for y0 in h_streets:
			ys.append(y0)
			ys.append(y0 + STREET_W)
		ys.append(size.y - 1)
		for j in range(0, ys.size(), 2):
			for i in range(0, xs.size(), 2):
				var r := Rect2i(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
				if r.size.x >= 4 and r.size.y >= 4:
					blocks.append(r)

	## The truck at the west end of a horizontal street, the player just south of it.
	func _place_entry() -> void:
		var y0: int = h_streets[rng.randi_range(0, h_streets.size() - 1)]
		var truck := Vector2i(2, y0 + 1)
		mark(truck, Vector2i(3, 1), true)
		out["truck"] = truck
		out["entry"] = truck + Vector2i(1, 1)
		set_ch(Vector2i(0, y0 + 1), "#")
		set_ch(Vector2i(0, y0 + 2), "#")
		set_ch(Vector2i(0, y0 + 3), "#")

	## The stairs in the block farthest from the truck that has a street below it. Returns that
	## block's index.
	func _place_stairs() -> int:
		var entry: Vector2i = out["entry"]
		var best := -1
		var best_d := -1.0
		for i in blocks.size():
			var b: Rect2i = blocks[i]
			if not _street_below(b):
				continue
			var d := Vector2(b.get_center()).distance_to(Vector2(entry))
			if d > best_d:
				best_d = d
				best = i
		if best < 0:
			best = blocks.size() - 1
		var b: Rect2i = blocks[best]
		var x := b.position.x + rng.randi_range(1, maxi(1, b.size.x - 3))
		var anchor := Vector2i(x, b.end.y - 2)
		fill(Rect2i(anchor.x - 1, anchor.y - 1, 4, 3), "c")
		mark(anchor, Vector2i(2, 2), true)
		# Reserve the approach (the sidewalk below) so no lamp or cone ever lands on it.
		mark(anchor + Vector2i(-1, 2), Vector2i(4, 1), false)
		out["stairs"] = anchor
		return best

	func _street_below(b: Rect2i) -> bool:
		return b.end.y < size.y - 1 and ch(Vector2i(b.position.x, b.end.y)) == "c"

	func _street_above(b: Rect2i) -> bool:
		return b.position.y > 1 and ch(Vector2i(b.position.x, b.position.y - 1)) == "c"

	# -- blocks --

	func _dress_block(b: Rect2i, has_stairs: bool) -> void:
		var weights: Dictionary = (BLOCK_WEIGHTS[theme] as Dictionary).duplicate()
		if not _street_below(b) or has_stairs:
			weights.erase("buildings")
		if depth < 2 or Vector2(b.get_center()).distance_to(Vector2(out["entry"])) < 18.0:
			weights.erase("camp")  # no raider camp on the truck's doorstep
		var role := pick_weighted(weights)
		if has_stairs:
			role = "plaza"  # an open square round the subway entrance; no walls across it
		match role:
			"buildings":
				_block_buildings(b)
			"ruin":
				_block_ruin(b)
			"lot":
				_block_lot(b)
			"rubble":
				_block_rubble(b)
			"plaza":
				_block_plaza(b)
			"yard":
				_block_yard(b)
			"camp":
				_block_camp(b)

	## A row of buildings fronting the street below, alleys between, a back yard behind.
	func _block_buildings(b: Rect2i) -> void:
		var kinds: Array = (BUILDINGS_BY_THEME[theme] as Array).duplicate()
		var x := b.position.x + rng.randi_range(0, 1)
		while x < b.end.x - 3:
			# The district's preferred kinds in a shuffled order; the first that fits wins.
			var order := kinds.duplicate()
			for i in range(order.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var t = order[i]
				order[i] = order[j]
				order[j] = t
			order.append("ruin_house")
			order.append("ruin_shopfront")
			var chosen := ""
			for k in order:
				var sz0: Vector2i = BUILDING_SIZE[String(k)]
				if x + sz0.x <= b.end.x and sz0.y + int(BUILDING_OVERHANG[String(k)]) + 1 <= b.size.y \
						and free_rect(Vector2i(x, b.end.y - sz0.y), sz0):
					chosen = String(k)
					break
			if chosen == "":
				x += 1
				continue
			var sz: Vector2i = BUILDING_SIZE[chosen]
			var anchor := Vector2i(x, b.end.y - sz.y)
			fill(Rect2i(anchor, sz), "X")
			mark(anchor, sz, true)
			(out["buildings"] as Array).append({"kind": chosen, "anchor": anchor, "size": sz})
			x += sz.x + rng.randi_range(1, 2)  # an alley
		# The back yard: dirt, junk, a container or two by the back doors.
		var yard_h := b.size.y - 4
		if yard_h >= 3:
			var yard := Rect2i(b.position.x, b.position.y, b.size.x, mini(yard_h, b.size.y - 3))
			_blob(yard, "r", 1)
			_some_breakables(yard, rng.randi_range(1, 2))
			_some_containers(yard, ["dumpster", "fridge", "locker"], rng.randi_range(0, 1))
			if rng.randf() < 0.5:
				_some_props(yard, ["tire_pile", "shopping_cart", "oil_drum"], 1)

	## A roofless ruin: walls with doorways; loot against the walls inside.
	func _block_ruin(b: Rect2i) -> void:
		var inset := 1
		var r := Rect2i(b.position + Vector2i(inset, inset), b.size - Vector2i(inset * 2, inset * 2))
		if r.size.x < 6 or r.size.y < 6:
			_block_lot(b)
			return
		fill(r.grow(-1), "c" if rng.randf() < 0.6 else "r")
		for x in range(r.position.x, r.end.x):
			set_ch(Vector2i(x, r.position.y), "F")
			set_ch(Vector2i(x, r.end.y - 1), "F")
		for y in range(r.position.y, r.end.y):
			set_ch(Vector2i(r.position.x, y), "F")
			set_ch(Vector2i(r.end.x - 1, y), "F")
		# Doorways: always one facing a street (south, else north), plus one or two more.
		var sides: Array[String] = []
		if _street_below(b):
			sides.append("s")
		elif _street_above(b):
			sides.append("n")
		for s in ["w", "e", "n", "s"]:
			if not sides.has(s) and rng.randf() < 0.45:
				sides.append(s)
		if sides.is_empty():
			sides.append("s")
		for s in sides:
			_doorway(r, s)
		# Broken walls: a gap or two knocked through at random.
		for i in rng.randi_range(0, 2):
			_doorway(r, ["w", "e", "n", "s"][rng.randi_range(0, 3)], 1)
		var inside := r.grow(-1)
		# An inner partition with a gap, for bigger ruins.
		if inside.size.x >= 7 and rng.randf() < 0.5:
			var px := inside.position.x + inside.size.x / 2
			var gap := inside.position.y + rng.randi_range(0, maxi(0, inside.size.y - 2))
			for y in range(inside.position.y, inside.end.y):
				if y != gap and y != gap + 1:
					set_ch(Vector2i(px, y), "F")
		var loot: Array = RUIN_LOOT[theme]
		_wall_containers(inside, loot, rng.randi_range(2, 3))
		if rng.randf() < 0.6:
			_some_breakables(inside, 1)
		if rng.randf() < 0.55:
			_note_in(inside)
		if rng.randf() < 0.4:
			_heaps(inside, 1)

	func _doorway(r: Rect2i, side: String, width: int = 2) -> void:
		match side:
			"s", "n":
				var x := rng.randi_range(r.position.x + 1, r.end.x - 1 - width)
				var y := r.end.y - 1 if side == "s" else r.position.y
				for i in width:
					set_ch(Vector2i(x + i, y), "c")
			"w", "e":
				var y := rng.randi_range(r.position.y + 1, r.end.y - 1 - width)
				var x := r.position.x if side == "w" else r.end.x - 1
				for i in width:
					set_ch(Vector2i(x, y + i), "c")

	## Parking lot: concrete with rows of wrecks, a dumpster, a searchable trunk.
	func _block_lot(b: Rect2i) -> void:
		var r := b.grow(-1)
		fill(r, "c")
		var rows_y := []
		var y := r.position.y + 1
		while y < r.end.y - 1:
			rows_y.append(y)
			y += 3
		for ry in rows_y:
			var x := r.position.x + rng.randi_range(0, 2)
			while x + 3 <= r.end.x:
				if rng.randf() < 0.55:
					var anchor := Vector2i(x, ry)
					if rng.randf() < 0.3:
						if open_rect(anchor, Vector2i(3, 1)):
							_add_container("car_trunk", anchor)
					elif open_rect(anchor, Vector2i(3, 1)):
						_add_prop(CARS[rng.randi_range(0, CARS.size() - 1)], anchor)
				x += 4
		_some_containers(r, ["dumpster"], rng.randi_range(0, 1))
		_some_props(r, ["tire_pile", "oil_drum", "shopping_cart", "traffic_cone"], rng.randi_range(1, 2))

	## A collapsed block: rubble ground, a few heaps, salvage to smash.
	func _block_rubble(b: Rect2i) -> void:
		var r := b.grow(-1)
		_blob(r, "r", 3)
		_heaps(r, rng.randi_range(3, 6))
		_some_breakables(r, rng.randi_range(2, 4))
		if rng.randf() < 0.5:
			_some_containers(r, ["supply_crate", "locker"], 1)
		if rng.randf() < 0.3:
			_note_in(r)

	## A paved square: lamps, a bench of wrecks, pickings at the edges.
	func _block_plaza(b: Rect2i) -> void:
		fill(b, "c")
		var r := b.grow(-1)
		_blob(r, "r", 1)
		_some_props(r, ["streetlamp_broken"], 3)
		_some_props(r, CARS, rng.randi_range(1, 2))
		_some_props(r, ["shopping_cart", "traffic_cone", "concrete_barrier", "tire_pile"], rng.randi_range(2, 4))
		_some_containers(r, ["supply_crate", "locker", "dumpster"], rng.randi_range(1, 2))
		_some_breakables(r, rng.randi_range(1, 2))
		_heaps(r, rng.randi_range(0, 2))

	## Industrial yard: walled concrete with drums, tyres and scrap, loot inside.
	func _block_yard(b: Rect2i) -> void:
		var r := b.grow(-1)
		fill(r, "c")
		for x in range(r.position.x, r.end.x):
			set_ch(Vector2i(x, r.position.y), "F")
		for y in range(r.position.y, r.end.y):
			set_ch(Vector2i(r.position.x, y), "F")
			set_ch(Vector2i(r.end.x - 1, y), "F")
		_doorway(r, "n", 2)
		_doorway(r, ["w", "e"][rng.randi_range(0, 1)], 2)
		var inside := Rect2i(r.position + Vector2i(1, 1), r.size - Vector2i(2, 1))
		_some_props(inside, ["oil_drum", "tire_pile", "oil_drum"], rng.randi_range(2, 3))
		_some_breakables(inside, rng.randi_range(2, 3), ["scrap_large", "scrap_small", "junk"])
		_wall_containers(inside, ["supply_crate", "locker"], rng.randi_range(1, 2))

	## Raiders: barricades in a horseshoe round a cache, the group inside.
	func _block_camp(b: Rect2i) -> void:
		var r := b.grow(-1)
		fill(r, "r")
		var c := r.get_center()
		var ring := Rect2i(c - Vector2i(3, 2), Vector2i(7, 5))
		for x in range(ring.position.x, ring.end.x - 1, 2):
			var a := Vector2i(x, ring.position.y)
			if free_rect(a, Vector2i(2, 1)):
				_add_prop("barricade" if rng.randf() < 0.6 else "concrete_barrier", a)
		for y in [ring.position.y + 2, ring.position.y + 3]:
			for x in [ring.position.x, ring.end.x - 1]:
				if free_rect(Vector2i(x, y), Vector2i.ONE):
					_add_prop("oil_drum", Vector2i(x, y))
		_some_containers(Rect2i(c - Vector2i(2, 0), Vector2i(5, 2)), ["supply_crate"], rng.randi_range(1, 2))
		var g := _new_group()
		for i in rng.randi_range(2, 3):
			var cell := c + Vector2i(i - 1, 1)
			if walkable(cell) and used[idx(cell)] == 0:
				(out["enemies"] as Array).append({"type": "raider", "cell": cell, "group": g})
				used[idx(cell)] = 1

	# -- block helpers --

	func _blob(r: Rect2i, s: String, count: int) -> void:
		for i in count:
			var c := rand_cell_in(r)
			var rad := rng.randf_range(1.4, 2.6)
			for y in range(c.y - 3, c.y + 4):
				for x in range(c.x - 3, c.x + 4):
					var p := Vector2i(x, y)
					if r.has_point(p) and Vector2(p - c).length() <= rad and ch(p) == ".":
						set_ch(p, s)

	func _heaps(r: Rect2i, count: int) -> void:
		for i in count * 3:
			if count <= 0:
				return
			var c := rand_cell_in(r)
			if open_rect(c, Vector2i.ONE):
				set_ch(c, "#")
				mark(c, Vector2i.ONE, true)
				count -= 1

	func _some_breakables(r: Rect2i, count: int, kinds: Array = ["scrap_small", "junk", "rock_small", "scrap_small"]) -> void:
		for i in count * 4:
			if count <= 0:
				return
			var c := rand_cell_in(r)
			var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
			var sz: Vector2i = BREAKABLE_SIZE.get(kind, Vector2i.ONE)
			if open_rect(c, sz):
				mark(c, sz, true)
				(out["breakables"] as Array).append({"kind": kind, "anchor": c})
				count -= 1

	func _some_props(r: Rect2i, kinds: Array, count: int) -> void:
		for i in count * 4:
			if count <= 0:
				return
			var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
			var a := rand_cell_in(r)
			if open_rect(a, PROP_SIZE.get(kind, Vector2i.ONE)):
				_add_prop(kind, a)
				count -= 1

	func _some_containers(r: Rect2i, kinds: Array, count: int) -> void:
		for i in count * 6:
			if count <= 0:
				return
			var kind := String(kinds[rng.randi_range(0, kinds.size() - 1)])
			var a := rand_cell_in(r)
			if open_rect(a, CONTAINER_SIZE.get(kind, Vector2i.ONE)):
				_add_container(kind, a)
				count -= 1

	## Containers standing against an inside wall (an open cell in front, open cells beside).
	func _wall_containers(inside: Rect2i, kinds: Array, count: int) -> void:
		for i in count * 10:
			if count <= 0:
				return
			var c := rand_cell_in(inside)
			if not free_rect(c, Vector2i.ONE):
				continue
			var against := 0
			var open := 0
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if ch(c + d) == "F":
					against += 1
				elif walkable(c + d) and used[idx(c + d)] == 0:
					open += 1
			if against == 1 and open == 3:
				_add_container(String(kinds[rng.randi_range(0, kinds.size() - 1)]), c)
				count -= 1

	func _note_in(r: Rect2i) -> void:
		for i in 12:
			var c := rand_cell_in(r)
			if free_rect(c, Vector2i.ONE):
				used[idx(c)] = 1
				(out["notes"] as Array).append(c)
				return

	func _add_prop(kind: String, anchor: Vector2i) -> void:
		mark(anchor, PROP_SIZE.get(kind, Vector2i.ONE), true)
		(out["props"] as Array).append({"kind": kind, "anchor": anchor})

	func _add_container(kind: String, anchor: Vector2i) -> void:
		mark(anchor, CONTAINER_SIZE.get(kind, Vector2i.ONE), true)
		(out["containers"] as Array).append({"kind": kind, "anchor": anchor, "tier": tier()})

	func _new_group() -> int:
		_group += 1
		return _group

	# -- streets --

	func _dress_streets() -> void:
		var truck: Vector2i = out["truck"]
		var keep_clear := Rect2i(truck - Vector2i(1, 2), Vector2i(9, 6))
		for y0 in h_streets:
			var x := 7
			while x < size.x - 6:
				var lane := y0 + rng.randi_range(1, 3)
				var roll := rng.randf()
				var a := Vector2i(x, lane)
				if keep_clear.has_point(a):
					x += 3
					continue
				if roll < 0.18 and theme != "residential" and lane <= y0 + 2 and open_rect(Vector2i(x, y0 + 1), Vector2i(6, 2)):
					_add_prop("bus_wreck", Vector2i(x, y0 + 1))
					x += 9
				elif roll < 0.5 and open_rect(a, Vector2i(3, 1)):
					_add_prop(CARS[rng.randi_range(0, CARS.size() - 1)], a)
					x += rng.randi_range(5, 8)
				elif roll < 0.62 and open_rect(a, Vector2i(2, 1)):
					_add_prop("barricade" if rng.randf() < 0.5 else "concrete_barrier", a)
					x += rng.randi_range(4, 7)
				elif roll < 0.75 and open_rect(a, Vector2i.ONE):
					_add_prop("traffic_cone", a)
					x += 3
				else:
					x += rng.randi_range(2, 4)
			# Broken lamps along the sidewalks.
			for side_y in [y0, y0 + STREET_W - 1]:
				var lx := rng.randi_range(4, 9)
				while lx < size.x - 2:
					var c := Vector2i(lx, side_y)
					if not keep_clear.has_point(c) and ch(c) == "c" and used[idx(c)] == 0 \
							and walkable(c + Vector2i.LEFT) and walkable(c + Vector2i.RIGHT):
						_add_prop("streetlamp_broken", c)
					lx += rng.randi_range(8, 12)
		for x0 in v_streets:
			var y := 3
			while y < size.y - 3:
				var a := Vector2i(x0 + rng.randi_range(1, 2), y)
				var roll := rng.randf()
				if roll < 0.25 and open_rect(a, Vector2i(2, 1)):
					_add_prop("concrete_barrier" if rng.randf() < 0.5 else "barricade", a)
				elif roll < 0.45 and open_rect(a, Vector2i.ONE):
					_add_prop(["traffic_cone", "tire_pile", "shopping_cart"][rng.randi_range(0, 2)], a)
				y += rng.randi_range(4, 7)

	## Dirt and rubble ground in blobs (never single scattered cells).
	## Tops the level up to its container quota, spreading the extras over random blocks.
	func _fill_containers() -> void:
		var quota: int = CONTAINER_QUOTA[clampi(depth, 1, 4) - 1]
		var kinds: Array = QUOTA_KINDS[theme]
		var guard := 0
		while (out["containers"] as Array).size() < quota and guard < 60:
			guard += 1
			_some_containers(blocks[rng.randi_range(0, blocks.size() - 1)].grow(-1), kinds, 1)

	func _ground_blobs() -> void:
		for b in blocks:
			if rng.randf() < 0.5:
				_blob(b.grow(-1), "r", 1)
		# Clean up: lone overlay cells read as polka dots; fold them back into the ground.
		for y in range(1, size.y - 1):
			for x in range(1, size.x - 1):
				var c := Vector2i(x, y)
				var s := ch(c)
				if s != ":" and s != "r":
					continue
				var same := 0
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if ch(c + d) == s:
						same += 1
				if same < 2:
					set_ch(c, ".")

	func _place_rad() -> void:
		var counts: Vector2i = RAD_COUNT[clampi(depth, 1, 4) - 1]
		var n := rng.randi_range(counts.x, counts.y)
		var entry: Vector2i = out["entry"]
		for i in n * 8:
			if n <= 0:
				return
			var b: Rect2i = blocks[rng.randi_range(0, blocks.size() - 1)] if rng.randf() < 0.6 \
				else Rect2i(1, h_streets[0], size.x - 2, STREET_W)
			var c := rand_cell_in(b)
			if Vector2(c).distance_to(Vector2(entry)) < 12.0:
				continue
			var strength := 2.0 + 0.4 * float(depth - 1)
			if rng.randf() < 0.55:
				if open_rect(c, Vector2i.ONE):
					mark(c, Vector2i.ONE, true)
					(out["rad"] as Array).append({"kind": "rad_barrel", "anchor": c, "strength": strength})
					n -= 1
			elif free_rect(c, Vector2i(2, 1)):
				mark(c, Vector2i(2, 1), false)  # a puddle is walkable: flat, not solid
				(out["rad"] as Array).append({"kind": "rad_puddle", "anchor": c, "strength": strength + 1.0})
				n -= 1

	func _scatter_decor() -> void:
		for y in range(1, size.y - 1):
			for x in range(1, size.x - 1):
				var c := Vector2i(x, y)
				if used[idx(c)] != 0:
					continue
				var s := ch(c)
				var roll := rng.randf()
				var kind := ""
				if s == "a" and roll < 0.025:
					kind = "manhole" if rng.randf() < 0.35 else "pavement_decor"
				elif s == "c" and roll < 0.02:
					kind = "pavement_decor"
				elif (s == "." or s == "r" or s == ":") and roll < 0.012:
					kind = "bones" if rng.randf() < 0.4 else "remains"
				if kind != "":
					used[idx(c)] = 1
					(out["decor"] as Array).append({"kind": kind, "cell": c})

	# -- enemies --

	func _place_enemies() -> void:
		var di := clampi(depth, 1, 4) - 1
		var counts: Vector2i = ENEMY_COUNT[di]
		var target := rng.randi_range(counts.x, counts.y)
		var have := (out["enemies"] as Array).size()
		var dist := _dist_from(out["entry"])
		var candidates: Array[Vector2i] = []
		for c in dist:
			if int(dist[c]) >= ENEMY_MIN_STEPS and used[idx(c)] == 0:
				candidates.append(c)
		candidates.sort()
		var mix: Dictionary = (ENEMY_MIX[di] as Dictionary).duplicate()
		mix.erase("raider")  # raiders come from camps (plus a roaming band deeper in)
		if depth >= 2 and have == 0:
			mix["raider"] = int((ENEMY_MIX[di] as Dictionary).get("raider", 0))
		var guard := 0
		while have < target and not candidates.is_empty() and guard < 200:
			guard += 1
			var c: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			if used[idx(c)] != 0:
				continue
			var type := pick_weighted(mix)
			var pack := 1
			var g := -1
			if type == "rad_hound" or type == "raider":
				pack = rng.randi_range(2, 3)
				g = _new_group()
			elif type == "shambler" and rng.randf() < 0.3:
				pack = 2
				g = _new_group()
			for i in pack:
				if have >= target and i > 0:
					break
				var cell: Vector2i = c + [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)][i]
				if not dist.has(cell) or used[idx(cell)] != 0:
					continue
				used[idx(cell)] = 1
				(out["enemies"] as Array).append({"type": type, "cell": cell, "group": g})
				have += 1

	func _dist_from(start: Vector2i) -> Dictionary:
		var dist := {start: 0}
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var c: Vector2i = queue[head]
			head += 1
			for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var n: Vector2i = c + d
				if dist.has(n) or not walkable(n):
					continue
				dist[n] = int(dist[c]) + 1
				queue.append(n)
		return dist

	## The last word: whatever the player can't reach is dropped (and the stairs' approach is
	## forced open if it ever comes to that).
	func _validate() -> void:
		var stairs: Vector2i = out["stairs"]
		var approach := stairs + Vector2i(0, 2)
		var dist := _dist_from(out["entry"])
		if not dist.has(approach):
			# Clear a lane straight down to the street, dropping anything standing in it.
			var lane := {}
			var c := approach
			while inb(c) and not dist.has(c):
				set_ch(c, "c")
				solid[idx(c)] = 0
				lane[c] = true
				c += Vector2i.DOWN
			for key in ["props", "containers", "breakables"]:
				var keep: Array = []
				for o in out[key]:
					var a := Vector2i(o["anchor"])
					var sz: Vector2i = PROP_SIZE.get(String(o["kind"]), CONTAINER_SIZE.get(String(o["kind"]),
						BREAKABLE_SIZE.get(String(o["kind"]), Vector2i.ONE)))
					var hit := false
					for dy in sz.y:
						for dx in sz.x:
							if lane.has(a + Vector2i(dx, dy)):
								hit = true
					if hit:
						mark(a, sz, false)
						for dy in sz.y:
							for dx in sz.x:
								solid[idx(a + Vector2i(dx, dy))] = 0
					else:
						keep.append(o)
				out[key] = keep
			dist = _dist_from(out["entry"])
		var reachable_side := func(anchor: Vector2i, sz: Vector2i) -> bool:
			for dy in range(-1, sz.y + 1):
				for dx in range(-1, sz.x + 1):
					var inside := dx >= 0 and dx < sz.x and dy >= 0 and dy < sz.y
					var corner := (dx < 0 or dx >= sz.x) and (dy < 0 or dy >= sz.y)
					if not inside and not corner and dist.has(anchor + Vector2i(dx, dy)):
						return true
			return false
		var kept: Array = []
		for c in out["containers"]:
			if reachable_side.call(Vector2i(c["anchor"]), CONTAINER_SIZE.get(String(c["kind"]), Vector2i.ONE)):
				kept.append(c)
		out["containers"] = kept
		kept = []
		for b in out["breakables"]:
			if reachable_side.call(Vector2i(b["anchor"]), BREAKABLE_SIZE.get(String(b["kind"]), Vector2i.ONE)):
				kept.append(b)
		out["breakables"] = kept
		kept = []
		for e in out["enemies"]:
			var ec := Vector2i(e["cell"])
			if dist.has(ec) and int(dist[ec]) >= ENEMY_MIN_STEPS:
				kept.append(e)
		out["enemies"] = kept
		kept = []
		for n in out["notes"]:
			if dist.has(Vector2i(n)):
				kept.append(n)
		out["notes"] = kept
