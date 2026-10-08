extends Node2D
## Per-zone world objects (2026-10-07; replaces farm.gd's two placeholder "resource nodes"):
## trees, stumps, rocks, scrap heaps, weeds, branches, junk and forage, defined in
## data/world_objects.json (rules in scripts/world_object_db.gd).
##
## A child of each zone map (scenes/test_map.tscn), sibling of Farm/Structures. Responsibilities:
## - build the layout-authored objects ('T' trees, 'O' salvage) and, for a fresh game, scatter
##   the overgrowth that the farm-reclaiming arc is about;
## - render each object as a y-sorted sprite anchored bottom-centre on its footprint, with a
##   collision body for solid kinds;
## - resolve tool hits (multi-hit HP, tier requirements, wobble/particles/sound feedback, trees
##   toppling) and spill drops into the world as scripts/pickup.gd pickups;
## - regrow debris and seasonal forage every morning (per-zone spawn tables below);
## - save/load the full object set.
##
## Objects live in `_objects` keyed by their ANCHOR (top-left footprint cell); `_occupancy` maps
## every footprint cell back to its anchor, so a hit on any cell of a 2x2 boulder resolves.

const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const Pickup := preload("res://scripts/pickup.gd")
const Calendar := preload("res://scripts/calendar.gd")
const MachineDB := preload("res://scripts/machine_db.gd")
const NightLight := preload("res://scripts/night_light.gd")
const READY_BUBBLE := preload("res://art/ui/ready_bubble.png")
const ItemDB := preload("res://scripts/item_db.gd")
const InventoryScript := preload("res://scripts/inventory.gd")
const LootDB := preload("res://scripts/loot_db.gd")

signal object_removed(anchor: Vector2i, kind: String)
## A placed chest was opened (Milestone B): main.gd routes this to the storage UI.
signal storage_opened(inventory, cell: Vector2i)
signal object_added(anchor: Vector2i, kind: String)
## Milestone C: Kael's truck was used (main.gd: ride out from the settlement / head home from
## the ruins), the subway stairs were taken, a container was searched.
signal vehicle_used(zone: String)
signal descent_used
signal container_searched(kind: String)

const CELL := 16

## Daily regrowth per zone: [min, max] new debris and forage per morning, caps on how many may
## exist, and the scatter density for a brand-new game (fraction of free grass cells covered).
const ZONE_SPAWNS := {
	"farm": {"debris": [3, 6], "debris_cap": 110, "forage": [0, 2], "forage_cap": 4, "trees": 0.15,
		"initial_density": 0.22},
	"path": {"debris": [1, 2], "debris_cap": 18, "forage": [1, 3], "forage_cap": 8, "trees": 0.3,
		"initial_density": 0.06},
	"ranch": {"debris": [0, 1], "debris_cap": 6, "forage": [0, 2], "forage_cap": 4, "trees": 0.0,
		"initial_density": 0.0},
	"town": {},
}
## Weighted debris mix for scatter and regrowth.
const DEBRIS_WEIGHTS := {"weeds": 46, "twig": 18, "pebble": 18, "junk": 7, "scrap_small": 5,
	"rock_small": 6}
## The old fields (',') start smothered: weeds and tall grass mostly, a few stones and sticks.
const OLD_FIELD_WEIGHTS := {"weeds": 50, "tallgrass": 22, "twig": 10, "pebble": 12, "rock_small": 6}
const OLD_FIELD_DENSITY := 0.62
## Rarer big objects for the initial scatter only (need tool upgrades; a reason to come back).
const BIG_SCATTER := {"rock_large": 4, "stump_large": 3, "log_large": 3, "scrap_large": 3}
## Cells around which nothing may spawn (radius in cells): the spawn point, gates, buildings.
const CLEAR_RADIUS_SPAWN := 4
const CLEAR_RADIUS_GATE := 2

var _test_map: Node2D = null
var _objects: Dictionary = {}     # anchor -> {kind, hp, variant}
var _occupancy: Dictionary = {}   # cell -> anchor
var _nodes: Dictionary = {}       # anchor -> Node2D
var _rng := RandomNumberGenerator.new()
var _season := "spring"
var _texture_cache: Dictionary = {}
## Trees currently drawn translucent because the player stands behind their canopy.
var _faded: Dictionary = {}
## Per-object state for player-placed kinds (Milestone B): anchor -> {"storage": Inventory,
## "machine": {output, count, ready_at, input, input_count} or {}, "days": passive counter}.
var _extra: Dictionary = {}
var _machine_clock := 0.0
## Milestone C: containers already searched (anchor -> true).
var _opened: Dictionary = {}


func _ready() -> void:
	_test_map = get_parent()
	y_sort_enabled = true
	_season = Calendar.season(DayManager.day)
	_rng.seed = hash([GameState.chosen_settlement_id, zone_id(), "objects"])
	_spawn_layout_objects()
	scatter_initial()
	DayManager.day_started.connect(_on_day_started)


func zone_id() -> String:
	return String(_test_map.get("zone_id")) if _test_map != null else ""


## -- Queries --

func has_object(cell: Vector2i) -> bool:
	return _occupancy.has(cell)


func anchor_of(cell: Vector2i) -> Vector2i:
	return _occupancy.get(cell, Vector2i(-9999, -9999))


## {kind, hp, variant} of whatever occupies `cell`, or {}.
func object_at(cell: Vector2i) -> Dictionary:
	if not _occupancy.has(cell):
		return {}
	return _objects.get(_occupancy[cell], {})


func kind_at(cell: Vector2i) -> String:
	return String(object_at(cell).get("kind", ""))


func is_solid_at(cell: Vector2i) -> bool:
	var obj := object_at(cell)
	return not obj.is_empty() and WorldObjectDB.is_solid(String(obj["kind"]))


func is_forage_at(cell: Vector2i) -> bool:
	var obj := object_at(cell)
	return not obj.is_empty() and WorldObjectDB.is_forage(String(obj["kind"]))


func count_kinds(kinds: Array) -> int:
	var n := 0
	for anchor in _objects:
		if kinds.has(String(_objects[anchor]["kind"])):
			n += 1
	return n


func all_objects() -> Dictionary:
	return _objects


## -- Placement --

## Whether `kind` could be placed with its top-left at `anchor` (in bounds, free terrain, no
## other object/plot/structure, not tilled soil).
func can_place(kind: String, anchor: Vector2i, for_player: bool = false) -> bool:
	if for_player and zone_id() == "ruins":
		return false  # the ruins are rebuilt every expedition: nothing the player sets down survives
	var size := WorldObjectDB.size_of(kind)
	var map_size: Vector2i = _test_map.layout.size()
	for dy in size.y:
		for dx in size.x:
			var c := anchor + Vector2i(dx, dy)
			if c.x < 1 or c.y < 1 or c.x >= map_size.x - 1 or c.y >= map_size.y - 1:
				return false
			if _occupancy.has(c) or _test_map.is_blocked_at(c):
				return false
			var t := String(_test_map.terrain_at(c))
			var ground_ok := t == "." or t == "," or t == "@" or t == "T" or t == "O"
			if for_player:
				# The player may set things down on paths and on bare tilled soil (a sprinkler in
				# the middle of a field), never on a growing crop.
				ground_ok = ground_ok or t == ":" or t == ";" or t == "p" or t == "f"
			if not ground_ok:
				return false
			if _test_map.is_soil_at(c.x, c.y) and not for_player:
				return false
			var farm: Node = _test_map.get_node_or_null("Farm")
			if farm != null and not farm.get_plot(c).is_empty():
				return false
	return true


func place(kind: String, anchor: Vector2i, variant: int = 0, hp: int = -1) -> bool:
	if not WorldObjectDB.has_kind(kind):
		return false
	if not can_place(kind, anchor):
		return false
	_add(kind, anchor, variant, hp)
	return true


## Puts a generated ruins object down as-is (main.gd's expedition loader: the generator already
## validated the footprint). `tier` is a container's loot tier. False if anything's in the way.
func add_generated(kind: String, anchor: Vector2i, tier: int = 1) -> bool:
	if not WorldObjectDB.has_kind(kind):
		return false
	var size := WorldObjectDB.size_of(kind)
	for dy in size.y:
		for dx in size.x:
			if _occupancy.has(anchor + Vector2i(dx, dy)):
				return false
	_add(kind, anchor, 1)
	if WorldObjectDB.container_of(kind) != "":
		_objects[anchor]["tier"] = tier
	return true


## The player sets `item_id` down at `cell` (Milestone B). True on success; the caller takes
## the item from the backpack.
func place_item(item_id: String, cell: Vector2i) -> bool:
	var kind := WorldObjectDB.kind_for_item(item_id)
	if kind == "" or not can_place(kind, cell, true):
		return false
	_add(kind, cell, 1)
	var center := _center_world(kind, cell)
	Audio.play_sfx_at("place_object", center)
	Fx.burst(center, "dust", Vector2.UP, 0.5)
	return true


func _add(kind: String, anchor: Vector2i, variant: int = 0, hp: int = -1) -> void:
	var v := variant if variant > 0 else _rng.randi_range(1, WorldObjectDB.variant_count(kind))
	_objects[anchor] = {"kind": kind, "hp": hp if hp > 0 else WorldObjectDB.hp_of(kind), "variant": v}
	if WorldObjectDB.is_placed(kind):
		var extra := {"machine": {}, "days": 0}
		if WorldObjectDB.storage_size(kind) > 0:
			extra["storage"] = InventoryScript.new()
		_extra[anchor] = extra
	var size := WorldObjectDB.size_of(kind)
	for dy in size.y:
		for dx in size.x:
			_occupancy[anchor + Vector2i(dx, dy)] = anchor
	_nodes[anchor] = _build_node(kind, anchor, v)
	object_added.emit(anchor, kind)


func remove(anchor: Vector2i) -> void:
	if not _objects.has(anchor):
		return
	var kind := String(_objects[anchor]["kind"])
	var size := WorldObjectDB.size_of(kind)
	for dy in size.y:
		for dx in size.x:
			_occupancy.erase(anchor + Vector2i(dx, dy))
	_objects.erase(anchor)
	_extra.erase(anchor)
	_opened.erase(anchor)
	var node: Node = _nodes.get(anchor)
	if node != null:
		node.queue_free()
	_nodes.erase(anchor)
	_faded.erase(anchor)
	object_removed.emit(anchor, kind)


func clear_all() -> void:
	for anchor in _objects.keys():
		remove(anchor)


## Milestone C: removes every loose pickup lying in this zone (the ruins between levels).
func clear_pickups() -> void:
	for child in get_children():
		if child is Pickup:
			child.queue_free()


## -- Interaction --

## A tool swing at `cell`. tool_kind is a farming tool kind or "weapon"; `hitter_pos` (world)
## decides which way a tree topples. Returns {"result": "none"|WRONG_TOOL|TOO_WEAK|"hit"|
## "destroyed", "kind", "drops"}. Drops are spilled into the world as pickups.
func hit(cell: Vector2i, tool_kind: String, tier: int, hitter_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	if not _occupancy.has(cell):
		return {"result": "none"}
	var anchor: Vector2i = _occupancy[cell]
	var obj: Dictionary = _objects[anchor]
	var kind := String(obj["kind"])
	var effect := WorldObjectDB.tool_effect(kind, tool_kind, tier)
	var node: Node2D = _nodes.get(anchor)
	var center := _center_world(kind, anchor)
	if effect == WorldObjectDB.WRONG_TOOL:
		return {"result": effect, "kind": kind}
	if WorldObjectDB.is_placed(kind) and not _storage_empty(anchor):
		Fx.wobble(node, 0.8)
		Fx.float_text(center + Vector2(0, -12), "Empty it first", Color("#ffc948"))
		return {"result": WorldObjectDB.WRONG_TOOL, "kind": kind}
	if effect == WorldObjectDB.TOO_WEAK:
		Audio.play_sfx_at("hit_metal" if kind.begins_with("scrap") else "mine", center, -4.0)
		Fx.wobble(node, 0.8)
		Fx.float_text(center + Vector2(0, -10), "Too tough!", Color("#ffc948"))
		return {"result": effect, "kind": kind}
	obj["hp"] = int(obj["hp"]) - WorldObjectDB.damage_for_tier(tier)
	_objects[anchor] = obj
	var preset := _particle_preset(kind)
	var away := (center - hitter_pos).normalized() if hitter_pos != Vector2.ZERO else Vector2.UP
	if int(obj["hp"]) > 0:
		Audio.play_sfx_at(WorldObjectDB.sound_hit(kind), center)
		Fx.wobble(node, 1.6 if WorldObjectDB.falls(kind) else 1.0)
		Fx.burst(center, preset, -away + Vector2.UP, 0.7)
		if WorldObjectDB.falls(kind):
			Fx.burst(center + Vector2(0, -26), _leaf_preset(), Vector2.DOWN, 0.6)
		return {"result": "hit", "kind": kind}
	return _destroy(anchor, kind, hitter_pos, center, away)


func _destroy(anchor: Vector2i, kind: String, hitter_pos: Vector2, center: Vector2,
		away: Vector2) -> Dictionary:
	if WorldObjectDB.is_placed(kind):
		return _pick_up_placed(anchor, kind, center, away)
	var drops := WorldObjectDB.roll_drops(kind, _rng)
	var node: Node2D = _nodes.get(anchor)
	var fall := WorldObjectDB.falls(kind) and node != null
	if fall:
		# Detach the sprite so it can topple while the stump appears underneath immediately.
		var sprite: Node2D = node.get_node_or_null("Sprite")
		if sprite != null:
			node.remove_child(sprite)
			add_child(sprite)
			sprite.global_position = node.global_position
			_topple(sprite, -1.0 if hitter_pos.x > center.x else 1.0)
		Audio.play_sfx_at("tree_creak", center, -2.0)
	else:
		Audio.play_sfx_at(WorldObjectDB.sound_break(kind), center)
		Fx.burst(center, _particle_preset(kind), Vector2.UP, 1.4)
		Fx.shake(0.6, 0.12)
	remove(anchor)
	var leftover := WorldObjectDB.becomes(kind)
	if leftover != "":
		_add(leftover, anchor)
	var fall_dir := -1.0 if hitter_pos.x > center.x else 1.0
	for d in drops:
		var origin := center
		if fall:
			origin = center + Vector2(fall_dir * _rng.randf_range(10.0, 34.0), _rng.randf_range(-4.0, 4.0))
		spawn_pickup(String(d["item_id"]), int(d["count"]), origin, away, 0.55 if fall else 0.0)
	Events.object_destroyed.emit(kind)
	var xp := WorldObjectDB.xp_of(kind)
	for skill in xp:
		Events.xp_gained.emit(String(skill), int(xp[skill]))
	return {"result": "destroyed", "kind": kind, "drops": drops}


## Picks up forage at `cell` straight into `inventory` (Stardew: forage goes to the pack).
## Returns {"item_id", "count"} or {} (nothing there / pack full).
func pick(cell: Vector2i, inventory) -> Dictionary:
	if not is_forage_at(cell):
		return {}
	var anchor: Vector2i = _occupancy[cell]
	var kind := String(_objects[anchor]["kind"])
	var item := WorldObjectDB.forage_item(kind)
	if item == "" or inventory == null or not inventory.can_add(item, 1):
		Events.message.emit("Your pack is full.")
		return {}
	inventory.add_item(item, 1)
	var center := _center_world(kind, anchor)
	remove(anchor)
	Audio.play_sfx_at("harvest", center)
	Fx.burst(center, "sparkle", Vector2.UP, 0.6)
	Events.item_gained.emit(item, 1)
	var xp := WorldObjectDB.xp_of(kind)
	for skill in xp:
		Events.xp_gained.emit(String(skill), int(xp[skill]))
	return {"item_id": item, "count": 1}


## Spills `count` of an item into the world as a pickup (delay lets a toppling tree land first).
func spawn_pickup(item_id: String, count: int, world_pos: Vector2, dir: Vector2 = Vector2.ZERO,
		delay: float = 0.0) -> void:
	if item_id == "" or count <= 0:
		return
	if delay > 0.0 and is_inside_tree():
		get_tree().create_timer(delay).timeout.connect(
			func() -> void: spawn_pickup(item_id, count, world_pos, dir, 0.0))
		return
	# Big stacks split into a few visible bundles so the pop feels generous.
	var bundles := clampi(count, 1, 4)
	var per := int(count / bundles)
	var extra := count - per * bundles
	for i in bundles:
		var p := Pickup.new()
		p.setup(item_id, per + (1 if i < extra else 0), dir, _rng)
		add_child(p)
		p.global_position = world_pos


## Debug/test helper: instantly delivers every pickup lying in this zone to `inventory`.
func collect_all_pickups(inventory) -> int:
	var collected := 0
	for child in get_children():
		if child is Pickup:
			var leftover: int = inventory.add_item(child.item_id, child.count)
			collected += child.count - leftover
			if leftover <= 0:
				child.queue_free()
			else:
				child.count = leftover
	return collected


## -- Spawning --

func _spawn_layout_objects() -> void:
	if _test_map.layout == null:
		return
	for entry in _test_map.layout.resource_node_cells():
		var cell: Vector2i = entry["cell"]
		var hashed := absi(hash([cell.x, cell.y, zone_id()]))
		var kind := ""
		if String(entry["kind"]) == "tree":
			kind = "tree_pine" if hashed % 3 == 0 else "tree_ashwood"
		else:
			kind = "scrap_small" if hashed % 2 == 0 else "rock_small"
		if not _occupancy.has(cell):
			_add(kind, cell)


## The fresh-game overgrowth. Deterministic per settlement + zone.
func scatter_initial() -> void:
	if not GameState.world_spawning_enabled:
		return
	var cfg: Dictionary = ZONE_SPAWNS.get(zone_id(), {})
	var density := float(cfg.get("initial_density", 0.0))
	if density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.chosen_settlement_id, zone_id(), "scatter"])
	var cells := _free_spawn_cells()
	# A few big obstacles first (they need room).
	var big_count := int(cells.size() * density * 0.02)
	for i in big_count:
		var kind := _weighted_pick(BIG_SCATTER, rng)
		var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		place(kind, c)
	if float(cfg.get("trees", 0.0)) > 0.0:
		for i in int(cells.size() * density * 0.03):
			var c2: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			place("tree_ashwood" if rng.randf() < 0.7 else "tree_pine", c2)
	for c3 in cells:
		var old_field := String(_test_map.layout.cell(c3.x, c3.y)) == ","
		var chance := maxf(density, OLD_FIELD_DENSITY) if old_field else density
		if rng.randf() < chance and not _occupancy.has(c3):
			place(_weighted_pick(OLD_FIELD_WEIGHTS if old_field else DEBRIS_WEIGHTS, rng), c3)


func _on_day_started(day: int) -> void:
	var new_season := Calendar.season(day)
	if new_season != _season:
		_season = new_season
		_refresh_all_textures()
		_clear_out_of_season_forage()
	spawn_daily(day)
	_tick_passive_producers()
	# Deferred: the farm's own morning pass (growth, then drying) runs on this same signal, and
	# sprinklers must water the NEW day's soil after it, not before.
	call_deferred("_run_sprinklers")


## Morning regrowth: some debris and this season's forage on free cells.
func spawn_daily(day: int) -> void:
	if not GameState.world_spawning_enabled:
		return
	var cfg: Dictionary = ZONE_SPAWNS.get(zone_id(), {})
	if cfg.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.chosen_settlement_id, zone_id(), day, "daily"])
	var cells := _free_spawn_cells()
	if cells.is_empty():
		return
	var debris_kinds := DEBRIS_WEIGHTS.keys()
	var debris_range: Array = cfg.get("debris", [0, 0])
	var n := rng.randi_range(int(debris_range[0]), int(debris_range[1]))
	if count_kinds(debris_kinds) < int(cfg.get("debris_cap", 0)):
		for i in n:
			place(_weighted_pick(DEBRIS_WEIGHTS, rng), cells[rng.randi_range(0, cells.size() - 1)])
	var forage_kinds := WorldObjectDB.kinds_spawning_on("forage_" + _season)
	var forage_range: Array = cfg.get("forage", [0, 0])
	var f := rng.randi_range(int(forage_range[0]), int(forage_range[1]))
	var all_forage: Array = []
	for k in WorldObjectDB.all_kinds():
		if WorldObjectDB.is_forage(String(k)):
			all_forage.append(String(k))
	if not forage_kinds.is_empty() and count_kinds(all_forage) < int(cfg.get("forage_cap", 0)):
		for i in f:
			place(forage_kinds[rng.randi_range(0, forage_kinds.size() - 1)],
				cells[rng.randi_range(0, cells.size() - 1)])
	if rng.randf() < float(cfg.get("trees", 0.0)) * 0.25:
		place("tree_ashwood" if rng.randf() < 0.7 else "tree_pine", cells[rng.randi_range(0, cells.size() - 1)])


func _clear_out_of_season_forage() -> void:
	for anchor in _objects.keys():
		var kind := String(_objects[anchor]["kind"])
		if WorldObjectDB.is_forage(kind):
			var layer := String(WorldObjectDB.get_kind(kind).get("spawn_on", ""))
			if layer != "forage_" + _season:
				remove(anchor)


## Grass cells where debris may appear: free, not near the spawn point, gates or buildings, and
## not where the player is standing.
func _free_spawn_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var layout = _test_map.layout
	var size: Vector2i = layout.size()
	var keep_clear: Array[Vector2i] = []
	var spawn: Vector2i = layout.spawn_cell()
	if String(layout.cell(spawn.x, spawn.y)) == "@":
		keep_clear.append(spawn)
	var gates: Array[Vector2i] = []
	for exit in layout.zone_exits():
		for g in exit["gate_cells"]:
			gates.append(g)
	var player_cell := Vector2i(-999, -999)
	var players := get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	if not players.is_empty():
		player_cell = _test_map.world_to_cell((players[0] as Node2D).global_position)
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var c := Vector2i(x, y)
			var t := String(layout.cell(x, y))
			if t != "." and t != ",":
				continue
			if _occupancy.has(c) or _test_map.is_blocked_at(c) or _test_map.is_soil_at(x, y) \
					or _test_map.has_floor(c):
				continue
			if absi(c.x - player_cell.x) <= 1 and absi(c.y - player_cell.y) <= 1:
				continue
			var near := false
			for k in keep_clear:
				if absi(k.x - x) <= CLEAR_RADIUS_SPAWN and absi(k.y - y) <= CLEAR_RADIUS_SPAWN:
					near = true
					break
			if not near:
				for g in gates:
					if absi(g.x - x) <= CLEAR_RADIUS_GATE and absi(g.y - y) <= CLEAR_RADIUS_GATE:
						near = true
						break
			if not near and _near_building(layout, c):
				near = true
			if not near:
				out.append(c)
	return out


func _near_building(layout, c: Vector2i) -> bool:
	for b in layout.buildings():
		var tl: Vector2i = b["top_left"]
		var sz: Vector2i = b["size"]
		if c.x >= tl.x - 1 and c.x <= tl.x + sz.x and c.y >= tl.y - 1 and c.y <= tl.y + sz.y + 1:
			return true
	return false


static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := rng.randi_range(0, maxi(total - 1, 0))
	for k in weights:
		roll -= int(weights[k])
		if roll < 0:
			return String(k)
	return String(weights.keys()[0])


## -- Rendering --

func _center_world(kind: String, anchor: Vector2i) -> Vector2:
	var size := WorldObjectDB.size_of(kind)
	var local := Vector2(anchor) * CELL + Vector2(size) * CELL * 0.5
	return _test_map.to_global(local)


func _build_node(kind: String, anchor: Vector2i, variant: int) -> Node2D:
	var size := WorldObjectDB.size_of(kind)
	var root := Node2D.new()
	root.name = "Obj_%d_%d" % [anchor.x, anchor.y]
	# Origin at the footprint's bottom-centre: y-sorting then compares ground lines.
	root.position = Vector2(anchor) * CELL + Vector2(size.x * CELL * 0.5, size.y * CELL)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	sprite.texture = _texture_for(kind, variant)
	var frames := WorldObjectDB.frames_of(kind)
	sprite.hframes = frames
	var tex_size := sprite.texture.get_size()
	sprite.offset = Vector2(-tex_size.x / frames * 0.5, -tex_size.y)
	root.add_child(sprite)
	var light_spec := WorldObjectDB.light_of(kind)
	if not light_spec.is_empty():
		var light := NightLight.make(Color(light_spec[0]), float(light_spec[1]), float(light_spec[2]),
			float(light_spec[4]) if light_spec.size() > 4 else 0.0)
		light.position = Vector2(0, -float(light_spec[3]))
		root.add_child(light)
	var work_spec := WorldObjectDB.work_light_of(kind)
	if not work_spec.is_empty():
		# A machine's fire: glows after dark only while a batch is cooking (_refresh_placed_visuals).
		var glow := NightLight.make(Color(work_spec[0]), float(work_spec[1]), float(work_spec[2]),
			float(work_spec[4]) if work_spec.size() > 4 else 0.0)
		glow.name = "WorkLight"
		glow.position = Vector2(0, -float(work_spec[3]))
		glow.visible = false
		root.add_child(glow)
	if WorldObjectDB.is_solid(kind):
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		if WorldObjectDB.falls(kind):
			rect.size = Vector2(10, 8)  # just the trunk
			shape.position = Vector2(0, -5)
		else:
			rect.size = Vector2(size) * CELL - Vector2(2, 2)
			shape.position = Vector2(0, -size.y * CELL * 0.5)
		shape.shape = rect
		body.add_child(shape)
		root.add_child(body)
	add_child(root)
	return root


func _texture_for(kind: String, variant: int) -> Texture2D:
	var path := WorldObjectDB.sprite_path(kind, _season, variant)
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = _fallback_texture(kind)
	_texture_cache[path] = tex
	return tex


func _refresh_all_textures() -> void:
	for anchor in _nodes:
		var obj: Dictionary = _objects.get(anchor, {})
		var sprite: Sprite2D = (_nodes[anchor] as Node2D).get_node_or_null("Sprite")
		if sprite == null or obj.is_empty():
			continue
		sprite.texture = _texture_for(String(obj["kind"]), int(obj["variant"]))
		var tex_size := sprite.texture.get_size()
		sprite.offset = Vector2(-tex_size.x / sprite.hframes * 0.5, -tex_size.y)


## Placeholder art (used only until the art/env sprites exist): simple palette shapes so the
## world stays readable during development.
func _fallback_texture(kind: String) -> Texture2D:
	var size := WorldObjectDB.size_of(kind)
	var w := size.x * CELL
	var h := size.y * CELL
	var img: Image
	if WorldObjectDB.falls(kind):
		img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in range(30, 48):
			for x in range(13, 19):
				img.set_pixel(x, y, Color("#5e4124"))
		var canopy := Color("#4a7232") if kind != "tree_dead" else Color("#78634c")
		for y in 34:
			for x in 32:
				if Vector2(x - 15.5, y - 17.0).length() < 14.5:
					img.set_pixel(x, y, canopy.lightened(0.15) if (x + y) % 7 == 0 else canopy)
		return ImageTexture.create_from_image(img)
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color("#8d877c")
	if kind.begins_with("scrap") or kind == "junk":
		col = Color("#a65c30")
	elif kind == "weeds" or kind == "tallgrass" or kind == "bush":
		col = Color("#5b9f4c")
	elif kind.begins_with("stump") or kind == "twig" or kind.begins_with("log"):
		col = Color("#7b5025")
	elif WorldObjectDB.is_forage(kind):
		col = Color("#e1982a")
	var r := minf(w, h) * 0.42
	for y in h:
		for x in w:
			if Vector2(x - w * 0.5, (y - h * 0.6) * 1.3).length() < r:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _particle_preset(kind: String) -> String:
	if kind.begins_with("tree") or kind.begins_with("stump") or kind == "twig" or kind.begins_with("log"):
		return "wood"
	if kind.begins_with("rock") or kind == "pebble":
		return "stone"
	if kind.begins_with("scrap") or kind == "junk":
		return "metal"
	return "grass"


func _leaf_preset() -> String:
	return "leaves_autumn" if _season == "autumn" else "leaves"


## Tree topple: rotate the detached sprite 90 degrees away from the chopper, then poof.
func _topple(sprite: Node2D, direction: float) -> void:
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "rotation", direction * PI * 0.5, 0.65).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		var landing := sprite.global_position + Vector2(direction * 24.0, -4.0)
		Fx.burst(landing, _leaf_preset(), Vector2.UP, 1.6)
		Fx.burst(landing, "dust", Vector2.UP, 1.2)
		Fx.shake(1.2, 0.18)
		Audio.play_sfx_at("tree_fall", landing))
	tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tw.tween_callback(sprite.queue_free)


## Trees go see-through while the player is behind their canopy (Stardew's readability trick).
func _process(delta: float) -> void:
	_machine_clock -= delta
	if _machine_clock <= 0.0:
		_machine_clock = 0.5
		_refresh_placed_visuals()
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Vector2 = (players[0] as Node2D).global_position
	for anchor in _nodes:
		var obj: Dictionary = _objects.get(anchor, {})
		if obj.is_empty() or not WorldObjectDB.fades(String(obj["kind"])):
			continue
		var node: Node2D = _nodes[anchor]
		var base: Vector2 = node.global_position
		var sprite: Sprite2D = node.get_node_or_null("Sprite")
		if sprite == null:
			continue
		# Behind = above the footprint's ground line, within the sprite's height and half-width.
		var half_w := maxf(22.0, sprite.texture.get_width() / float(sprite.hframes) * 0.5 - 4.0)
		var tall := maxf(60.0, sprite.texture.get_height() - 4.0)
		var behind: bool = p.y < base.y - 2.0 and p.y > base.y - tall and absf(p.x - base.x) < half_w
		if behind and not _faded.has(anchor):
			_faded[anchor] = true
			sprite.modulate.a = 0.55
		elif not behind and _faded.has(anchor):
			_faded.erase(anchor)
			sprite.modulate.a = 1.0


## -- Save / load --

func save_state() -> Dictionary:
	var out := {}
	for anchor in _objects:
		var obj: Dictionary = _objects[anchor]
		var entry := {"kind": obj["kind"], "hp": obj["hp"], "variant": obj["variant"]}
		var extra: Dictionary = _extra.get(anchor, {})
		if extra.has("storage"):
			var inv = extra["storage"]
			entry["storage"] = SaveData.encode_inventory(inv.slots, 0)
		if not (extra.get("machine", {}) as Dictionary).is_empty():
			entry["machine"] = (extra["machine"] as Dictionary).duplicate()
		if int(extra.get("days", 0)) > 0:
			entry["days"] = int(extra["days"])
		out[SaveData.cell_key(anchor)] = entry
	return {"objects": out}


## Restores a saved object set, replacing whatever _ready() built. `legacy_resource_nodes` is the
## pre-2026-10-07 farm save's {cell: "tree"|"ore"} map: when the save predates world objects,
## only the layout objects still listed there survive (chopped ones stay gone).
func load_state(data: Dictionary, legacy_resource_nodes = null) -> void:
	if data.has("objects"):
		clear_all()
		var saved: Dictionary = data.get("objects", {})
		for key in saved:
			var o: Dictionary = saved[key]
			var kind := String(o.get("kind", ""))
			if not WorldObjectDB.has_kind(kind):
				continue
			var anchor := SaveData.parse_cell_key(String(key))
			_add(kind, anchor, int(o.get("variant", 1)), int(o.get("hp", -1)))
			_restore_extra(anchor, o)
		_refresh_placed_visuals()
		return
	if legacy_resource_nodes is Dictionary:
		for anchor in _objects.keys():
			var kind := String(_objects[anchor]["kind"])
			if (kind.begins_with("tree") or kind == "scrap_small" or kind == "rock_small") \
					and not (legacy_resource_nodes as Dictionary).has(anchor):
				remove(anchor)



## -- Player-placed objects: chests, sprinklers, machines (Milestone B, 2026-10-07) --

func storage_at(cell: Vector2i):
	var extra: Dictionary = _extra.get(anchor_of(cell), {})
	return extra.get("storage")


func machine_state_at(cell: Vector2i) -> Dictionary:
	var extra: Dictionary = _extra.get(anchor_of(cell), {})
	return extra.get("machine", {})


func _storage_empty(anchor: Vector2i) -> bool:
	var extra: Dictionary = _extra.get(anchor, {})
	var inv = extra.get("storage")
	if inv != null:
		for slot in inv.slots:
			if not (slot as Dictionary).is_empty():
				return false
	return true


## Searches a ruins container once: its loot (scripts/loot_db.gd, by the container's table and
## tier) spills out toward the player, the sprite shows its searched frame, scavenging XP.
func _search(anchor: Vector2i, player) -> void:
	var kind := String(_objects[anchor]["kind"])
	_opened[anchor] = true
	var node: Node2D = _nodes.get(anchor)
	var sprite: Sprite2D = node.get_node_or_null("Sprite") if node != null else null
	var open_path := WorldObjectDB.open_sprite(kind)
	if sprite != null and sprite.hframes > 1:
		sprite.frame = 1
	elif sprite != null and open_path != "" and ResourceLoader.exists(open_path):
		sprite.texture = load(open_path)
	elif sprite != null:
		sprite.modulate = Color(0.78, 0.78, 0.78, 1.0)
	var center := _center_world(kind, anchor)
	Audio.play_sfx_at("container_open", center, -2.0)
	Fx.burst(center + Vector2(0, -6), "dust", Vector2.UP, 0.7)
	if node != null:
		Fx.wobble(node, 1.0, 0.15)
	var toward: Vector2 = Vector2.DOWN
	if player != null and player is Node2D:
		toward = ((player as Node2D).global_position - center).normalized()
	var drops := _roll_container(WorldObjectDB.container_of(kind), int(_objects[anchor].get("tier", 1)))
	if drops.is_empty():
		Fx.float_text(center + Vector2(0, -18), "Nothing useful", Color("#b5a98c"))
	for i in drops.size():
		var d: Dictionary = drops[i]
		spawn_pickup(String(d["item_id"]), int(d["count"]), center + Vector2(0, -4),
			toward.rotated(_rng.randf_range(-0.6, 0.6)), 0.05 * i)
	Events.xp_gained.emit("scavenging", 3)
	container_searched.emit(kind)


func _roll_container(table_id: String, tier: int) -> Array:
	return LootDB.roll(table_id, tier, _rng) if table_id != "" else []


func is_opened(cell: Vector2i) -> bool:
	return _opened.has(anchor_of(cell))


## What Interact would do at `cell` with `held_item` selected: "Open", "Collect", "Load" or "".
func instant_verb(cell: Vector2i, held_item: String) -> String:
	if not _occupancy.has(cell):
		return ""
	var anchor: Vector2i = _occupancy[cell]
	var kind := String(_objects[anchor]["kind"])
	if WorldObjectDB.container_of(kind) != "":
		return "" if _opened.has(anchor) else "Search"
	if WorldObjectDB.is_vehicle(kind):
		return "Head home" if zone_id() == "ruins" else "Ride out"
	if WorldObjectDB.is_descent(kind):
		return "Go deeper"
	if not WorldObjectDB.is_placed(kind):
		return ""
	if WorldObjectDB.storage_size(kind) > 0:
		return "Open"
	var machine := WorldObjectDB.machine_of(kind)
	if machine == "":
		return ""
	var state: Dictionary = _extra.get(anchor, {}).get("machine", {})
	if not state.is_empty():
		return "Collect" if _is_ready(state) else ""
	if held_item != "" and MachineDB.accepts(machine, held_item):
		return "Load"
	return ""


## Interact with a placed object: open a chest, collect a finished batch, load the held item, or
## report what the machine is doing. True when there was something to interact with.
func interact_placed(cell: Vector2i, player) -> bool:
	if not _occupancy.has(cell):
		return false
	var anchor: Vector2i = _occupancy[cell]
	var kind := String(_objects[anchor]["kind"])
	if WorldObjectDB.container_of(kind) != "":
		if not _opened.has(anchor):
			_search(anchor, player)
		return true
	if WorldObjectDB.is_vehicle(kind):
		vehicle_used.emit(zone_id())
		return true
	if WorldObjectDB.is_descent(kind):
		descent_used.emit()
		return true
	if not WorldObjectDB.is_placed(kind):
		return false
	var center := _center_world(kind, anchor)
	var extra: Dictionary = _extra.get(anchor, {})
	if extra.has("storage"):
		Audio.play_sfx("chest_open", -4.0)
		storage_opened.emit(extra["storage"], cell)
		return true
	var machine := WorldObjectDB.machine_of(kind)
	if machine == "":
		return false
	var state: Dictionary = extra.get("machine", {})
	if not state.is_empty():
		if not _is_ready(state):
			var left := int(state["ready_at"]) - _now()
			Fx.float_text(center + Vector2(0, -20), "Ready in %s" % _duration_text(left), Color("#ffedb1"))
			return true
		var item := String(state["output"])
		var count := int(state["count"])
		if not player.inventory.can_add(item, count):
			Events.message.emit("Your pack is full.")
			return true
		player.inventory.add_item(item, count)
		Events.item_gained.emit(item, count)
		Events.xp_gained.emit("crafting", 2)
		extra["machine"] = {}
		Audio.play_sfx_at("pickup", center, -2.0)
		Fx.burst(center + Vector2(0, -8), "sparkle", Vector2.UP, 0.8)
		_refresh_placed_visuals()
		return true
	var held := String(player.inventory.get_selected_slot().get("item_id", ""))
	var recipe := MachineDB.recipe_for(machine, held)
	if recipe.is_empty():
		Fx.float_text(center + Vector2(0, -20), MachineDB.display_name(machine), Color("#ffedb1"))
		return true
	var fuel := String(recipe.get("fuel", ""))
	if not MachineDB.can_load(recipe, player.inventory.count_of(held),
			player.inventory.count_of(fuel) if fuel != "" else 0):
		var need := "%d %s" % [int(recipe["count"]), ItemDB.display_name(held)]
		if fuel != "" and player.inventory.count_of(fuel) < int(recipe.get("fuel_count", 1)):
			need += " + %d %s" % [int(recipe.get("fuel_count", 1)), ItemDB.display_name(fuel)]
		Fx.float_text(center + Vector2(0, -20), "Needs " + need, Color("#ffb72d"))
		return true
	player.inventory.remove_item(held, int(recipe["count"]))
	if fuel != "":
		player.inventory.remove_item(fuel, int(recipe.get("fuel_count", 1)))
	extra["machine"] = {"output": String(recipe["output"]), "count": int(recipe.get("out_count", 1)),
		"ready_at": _now() + int(recipe.get("minutes", 60)), "input": held,
		"input_count": int(recipe["count"])}
	Audio.play_sfx_at("machine_load" if ResourceLoader.exists("res://audio/sfx/machine_load.wav") else "place_object", center)
	Fx.burst(center, "dust", Vector2.UP, 0.5)
	_refresh_placed_visuals()
	return true


func _now() -> int:
	return MachineDB.absolute_minutes(DayManager.day, DayManager.minutes_into_day)


func _is_ready(state: Dictionary) -> bool:
	return not state.is_empty() and _now() >= int(state.get("ready_at", 0))


static func _duration_text(minutes: int) -> String:
	if minutes >= 1440:
		return "%d days" % ceili(minutes / 1440.0)
	if minutes >= 60:
		return "%dh" % ceili(minutes / 60.0)
	return "%dm" % maxi(minutes, 1)


## Working machines show their lit frame; finished ones float their product above them.
func _refresh_placed_visuals() -> void:
	for anchor in _extra:
		var obj: Dictionary = _objects.get(anchor, {})
		var node: Node2D = _nodes.get(anchor)
		if obj.is_empty() or node == null:
			continue
		var kind := String(obj["kind"])
		var sprite: Sprite2D = node.get_node_or_null("Sprite")
		var state: Dictionary = (_extra[anchor] as Dictionary).get("machine", {})
		var working := not state.is_empty() and not _is_ready(state)
		var has_fire := not WorldObjectDB.work_light_of(kind).is_empty()
		if sprite != null and sprite.hframes > 1:
			var nf := WorldObjectDB.night_frame(kind)
			if nf >= 0:
				var m := DayManager.minutes_into_day
				sprite.frame = nf if (m >= 18.5 * 60.0 or m < 6.0 * 60.0) else 0
			else:
				# Fires go out when the batch is done; jars and the like stay full until collected.
				sprite.frame = 1 if (working if has_fire else not state.is_empty()) else 0
		var work_light: Node2D = node.get_node_or_null("WorkLight")
		if work_light != null:
			work_light.visible = working
		var bubble: Sprite2D = node.get_node_or_null("Ready")
		var ready := _is_ready(state)
		if ready and bubble == null:
			# A cream thought bubble holding the product's icon, bobbing just above the machine;
			# drawn over neighbouring objects so it reads from anywhere on screen.
			bubble = Sprite2D.new()
			bubble.name = "Ready"
			bubble.texture = READY_BUBBLE
			bubble.centered = false
			bubble.z_index = 4
			var tex_h := sprite.texture.get_size().y if sprite != null else 16.0
			bubble.position = Vector2(-READY_BUBBLE.get_width() / 2.0, -tex_h - READY_BUBBLE.get_height() + 1.0)
			var icon := Sprite2D.new()
			icon.centered = false
			icon.position = Vector2(2, 2)
			var icon_path := ItemDB.icon_path(String(state["output"]))
			if ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
			bubble.add_child(icon)
			node.add_child(bubble)
			var tw := bubble.create_tween().set_loops()
			tw.tween_property(bubble, "position:y", bubble.position.y - 2.0, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(bubble, "position:y", bubble.position.y, 0.5).set_trans(Tween.TRANS_SINE)
		elif not ready and bubble != null:
			node.remove_child(bubble)
			bubble.queue_free()


## Picking a placed object back up: the object's own item, plus a machine's batch (finished
## output, or the input handed back if it was still working).
func _pick_up_placed(anchor: Vector2i, kind: String, center: Vector2, away: Vector2) -> Dictionary:
	var drops: Array[Dictionary] = [{"item_id": WorldObjectDB.item_of(kind), "count": 1}]
	var state: Dictionary = (_extra.get(anchor, {}) as Dictionary).get("machine", {})
	if not state.is_empty():
		if _is_ready(state):
			drops.append({"item_id": String(state["output"]), "count": int(state["count"])})
		elif String(state.get("input", "")) != "":
			drops.append({"item_id": String(state["input"]), "count": int(state.get("input_count", 1))})
	Audio.play_sfx_at(WorldObjectDB.sound_break(kind), center)
	Fx.burst(center, "dust", Vector2.UP, 0.8)
	remove(anchor)
	for d in drops:
		spawn_pickup(String(d["item_id"]), int(d["count"]), center, away)
	return {"result": "destroyed", "kind": kind, "drops": drops}


## Morning watering: every sprinkler waters the soil cells in its pattern (after the farm's own
## morning pass — see _on_day_started).
func _run_sprinklers() -> void:
	var farm: Node = _test_map.get_node_or_null("Farm")
	if farm == null:
		return
	for anchor in _objects:
		var level := WorldObjectDB.sprinkler_level(String(_objects[anchor]["kind"]))
		if level <= 0:
			continue
		for cell in WorldObjectDB.sprinkler_cells(anchor, level):
			if farm.is_soil(cell):
				farm.water(cell)


## Bee boxes and rad rods: produce on their own each morning when due.
func _tick_passive_producers() -> void:
	for anchor in _extra:
		var obj: Dictionary = _objects.get(anchor, {})
		if obj.is_empty():
			continue
		var machine := WorldObjectDB.machine_of(String(obj["kind"]))
		var rule := MachineDB.produces(machine)
		if rule.is_empty():
			continue
		var extra: Dictionary = _extra[anchor]
		if not (extra.get("machine", {}) as Dictionary).is_empty():
			continue  # the last batch is still waiting to be collected
		extra["days"] = int(extra.get("days", 0)) + 1
		if MachineDB.passive_due(rule, int(extra["days"]), String(DayManager.weather_today)):
			extra["machine"] = {"output": String(rule["output"]), "count": int(rule.get("out_count", 1)),
				"ready_at": _now(), "input": "", "input_count": 0}
			extra["days"] = 0
	_refresh_placed_visuals()


func _restore_extra(anchor: Vector2i, o: Dictionary) -> void:
	if not _extra.has(anchor):
		return
	var extra: Dictionary = _extra[anchor]
	if extra.has("storage") and o.get("storage") is Dictionary:
		var decoded := SaveData.decode_inventory(o["storage"])
		extra["storage"].restore(decoded.get("slots", []), 0)
	if o.get("machine") is Dictionary:
		var m: Dictionary = o["machine"]
		extra["machine"] = {"output": String(m.get("output", "")), "count": int(m.get("count", 1)),
			"ready_at": int(m.get("ready_at", 0)), "input": String(m.get("input", "")),
			"input_count": int(m.get("input_count", 0))}
	extra["days"] = int(o.get("days", 0))
