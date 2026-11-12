extends Node2D
## Phase 4 building layer: spawns the farmhouse, mayor's fortified house, Marta's store, settler
## shacks, storage chest, and bulletin board as real, collidable volumes — one StaticBody2D +
## one visual per building, sized to its footprint (top_left + size in cells, from
## scripts/map_layouts/*.gd's buildings() list). Phase 6 Art pass 1: the visual is now a
## Sprite2D with the kind's real PixelLab art when art/buildings/<kind>.png exists, falling back
## to the original flat-color fill (see _building_texture) — same fallback pattern as farm.gd's
## _crop_texture.
##
## ROADMAP.md Phase 4 scope: these are placeholder volumes, not full art/interiors — no NPCs live
## in them yet (Phase 5) and no interiors exist. Interactable: the chest (storage), the farmhouse
## bed (Phase 4 Stage 3: sleep = auto-save + skip to next morning — see is_bed_at() and
## player.gd's _sleep_in_bed()), and the shipping box (Phase 5 Stage 3: load harvested crops, and
## the sale resolves on the next day_started — see the shipping section below). The bulletin
## board is deliberately inert (no quest system yet).
##
## Expected in the scene tree as a child of TestMap (see scenes/test_map.tscn), sibling to Farm,
## so get_parent() is the TestMap node whose `layout` this reads building data from — same
## ordering guarantee TestMap.gd documents (`layout` is set in TestMap._enter_tree(), which runs
## before this node's _ready() since _enter_tree is top-down and _ready is bottom-up).
##
## Phase 4 Stage 2 ("Basic building placement") extends this same node to also own RUNTIME-placed
## buildings, not just layout-authored ones: scripts/builder.gd's placement mode calls
## can_place()/place_blueprint() here, a placed blueprint is immediately a real collidable body
## (rendered translucent blueprint-blue so it reads as "under construction"), and completion rides
## DayManager.day_started exactly the way farm.gd's crop growth does — no separate timer. A
## completed structure gets its kind's final BUILDING_COLORS fill; a completed storage structure
## (BuildingDB.is_storage) additionally becomes a working chest via the same chest_toggled
## signal/UI the layout chest already uses.
##
## Phase 8 Stage 2 (fencing & perimeter system): fence/gate catalog entries are placed through
## this exact same builder.gd flow — nothing new there, just 4 more BuildingDB ids. What IS new:
## a completed structure's collision now depends on BuildingDB.solid() (see
## _spawn_footprint_body's `solid` param) — true for every pre-existing building and every fence,
## false only for the Gate, whose completed cell is explicitly unblocked (test_map.unblock_cells)
## so it reads as a walkable opening in an otherwise-solid perimeter. can_place()'s new
## _is_footprint_occupied() guard is what stops a second structure from then being built on top
## of that now-unblocked Gate cell.

const Inventory := preload("res://scripts/inventory.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const BuildingEffects := preload("res://scripts/building_effects.gd")
const BuildGrid := preload("res://scripts/build_grid.gd")
const FarmGrid := preload("res://scripts/farm_grid.gd")
const SaveData := preload("res://scripts/save_data.gd")
const ShippingDB := preload("res://scripts/shipping_db.gd")

signal chest_toggled(inventory: Inventory, cell: Vector2i)
## Phase 5 Stage 3: a shipping-box sale resolved this morning — `total` is the Credits credited.
## main.gd wires this straight to player.add_credits (the Stage 2-documented hook), keeping this
## node player-agnostic the same way chest_toggled keeps it UI-agnostic. The itemized entry just
## appended to sale_history carries the full breakdown for anything that wants more than the sum.
signal crops_sold(total: int)
## Phase 8 Stage 1: the accumulated BuildingDB.daily_yield() across every completed structure in
## this zone, emitted ONCE per morning if non-empty (a Workshop's scrap trickle, a Greenhouse's
## seedling, etc. all land in the one dict). main.gd wires this straight to player.add_items,
## exactly the crops_sold -> player.add_credits pattern above — this node stays inventory-
## agnostic (never touches player directly), only ever emitting.
signal building_yield_produced(items: Dictionary)

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
	# Phase 4 Stage 2 player-buildable kinds (data/buildings.json):
	"shelter_tent": "#95ac49",    # faded field green — a salvaged-tarp lean-to
	"storage_shed": "#7d452a",    # rusted iron-brown — a scrap-sheet storage hut
	"barn": "#a23a2a",            # faded barn red — player livestock housing
	"coop": "#c9a24b",            # straw/wood gold — player poultry housing
	# Phase 8 Stage 1: the 10 new functional building-library kinds (data/buildings.json),
	# every hex distinct from the above and from each other at the 16px tile scale, drawing on
	# GDD.md §9's locked settlement-anchor + seasonal palette where a hex was still unused there,
	# with a few bespoke near-palette variants (workshop tools, a clinic's pale bandage-white, a
	# scavenged-tech grey) following the same precedent as the existing ranch/shipping-box hexes:
	"workshop": "#5d7d3a",        # deep leaf green — reclaimed timber and tool-shed greenery
	"clinic": "#d9cfc1",          # pale bone/bandage tone — reads clean against the amber town
	"trading_post": "#d4a017",    # golden ochre — an economic building, distinct from store's amber
	"watchtower": "#6a4626",      # wet soil dark — a tall weathered-timber lookout
	"greenhouse": "#6cb34d",      # fresh rain-fed green — glass-and-plant growing house
	"compost_pit": "#488c55",     # damp moss green — an earthy compost heap
	"rain_collector": "#7fa1b7",  # rain-sky blue-grey — the same rain-sky hue as its own function
	"solar_panel": "#3a3f4b",     # dark scavenged-tech slate — salvaged panels, not GDD's warm set
	"antenna_tower": "#707a7d",   # weathered antenna-grey — a technical mast, distinct from metal
	"community_kitchen": "#895a2e", # tilled soil brown — a warm, homely hearth building
	# Phase 4 Stage 3: the farmhouse bed (sleep = save + skip to morning), authored in each
	# layout beside the farmhouse the same way the chest is:
	"bed": "#f3acb7",             # mutant blossom pink (GDD §9 seasonal set) — reads as a blanket
	# Phase 5 Stage 3: the shipping box (load crops, sleep, Credits next morning), the third
	# authored 1x1 interactable in the farmhouse's service row (chest / box / bed):
	"shipping_box": "#c5520f",    # rust red — a scrap-metal shipping crate, distinct from the
	                              # chest's gold and the bed's pink at a glance
	# Ranch/Sanctuary scenery buildings (MAPS.md §3): the keeper's home/shop, barn, and coop in
	# the southern compound. Fallback fills only — real PixelLab art ships at art/buildings/<kind>.png.
	"ranch_house": "#9c5a3c",     # weathered timber ranch house/shop
	"ranch_barn": "#a23a2a",      # faded barn red
	"ranch_coop": "#c9a24b",      # straw/wood coop
	# Phase 8 Stage 2 (fencing & perimeter system): fence_wood/fence_chainlink/fence_concrete all
	# share kind "fence" (a material/cost/durability variant, not a visually distinct kind per the
	# plan), so all three placeholder-render identically here — matches the shared "kind" schema
	# exactly, same as e.g. every crop sharing "chest"'s single fallback would if that existed.
	"fence": "#6b5b47",           # weathered driftwood-brown — a plain perimeter barrier
	"gate": "#b8935a",            # lighter worn-wood tan, distinct from fence's darker brown
}

## Under-construction fill for a placed blueprint: the GDD §9 rain-sky blue-grey at ~half alpha,
## because translucent blue is the universal "blueprint" read and no completed building uses it.
const BLUEPRINT_COLOR := Color("#7fa1b7", 0.55)

## One real second Inventory (ROADMAP.md Phase 4: "opens a second Inventory instance... giving
## the player extra storage") backing the farmland's storage chest. Reused verbatim from
## scripts/inventory.gd per the scope note; see this session's report for the documented
## limitation that item-transfer UX (drag/move-in) is deferred, not just display/toggle.
var chest_inventory: Inventory = Inventory.new()

var _test_map: Node2D
var _chest_cell: Vector2i = Vector2i(-1, -1)
## The farmhouse bed's cell (Phase 4 Stage 3) — same one-marked-cell pattern as _chest_cell.
var _bed_cell: Vector2i = Vector2i(-1, -1)
## The shipping box's cell (Phase 5 Stage 3) — third instance of the same pattern.
var _shipping_box_cell: Vector2i = Vector2i(-1, -1)
var _bodies: Array[StaticBody2D] = []

## -- Phase 5 Stage 3: shipping-box state (lives HERE rather than on a new sibling node because
## this node already owns every other authored interactable's state — the chest's Inventory, the
## bed's cell — plus the day_started subscription the sale resolves on; a whole new node would
## exist only to hold two fields and re-subscribe to the same signal. The pure math it defers to
## is scripts/shipping_db.gd, mirroring the shop_db.gd/store_ui.gd split.) --

## Pending, not-yet-sold contents: {item_id: count}. One-way (Stardew convention): crops go in
## via add_to_shipping_box(), and the only way out is the overnight sale — no retrieval UX to
## build or save-scum. Cleared each morning it resolves.
var shipping_contents: Dictionary = {}
## One entry per morning a non-empty box sold: {day, items: {item_id: count}, total} — see
## shipping_db.gd's class doc for the field reasoning. Kept in full (never truncated): entries
## are a few dozen bytes each and a real playthrough sleeps ~112 times a year, so even a long
## save stays trivially small — and a future ledger UI gets the complete record for free.
var sale_history: Array = []

## Runtime-placed structures (Phase 4 Stage 2). Each entry: {building_id, kind, top_left, size,
## placed_day, visual} — visual is the body's visual node (blueprint ColorRect while pending;
## swapped for the final textured/flat Sprite2D on completion — see _complete_construction).
var _pending: Array[Dictionary] = []
var _completed: Array[Dictionary] = []
## Completed storage structures' own Inventory instances, keyed by top_left — one fresh instance
## per built Storage Shed, exactly the chest_inventory pattern generalized.
var _storage_inventories: Dictionary = {}

## Milestone B (2026-10-08, Town Works): multiplies the overnight shipping sale (1.1 once Marta's
## shopfront is rebuilt — main.gd sets it), the layout buildings' visuals by building id (so a
## finished project can swap the store's or the clinic's art), the notice board's cell, and the
## buildings Town Works adds (rebuilt from the quests state at boot, so never saved here).
var sale_multiplier := 1.0
## Milestone D: the market (scripts/market.gd), assigned by main.gd; null in bare tests, where
## shipments sell at list price.
var market: Node = null
var _layout_visuals: Dictionary = {}
var _layout_kinds: Dictionary = {}
var _board_cell := Vector2i(-1, -1)
var _works: Dictionary = {}
var _works_rects: Dictionary = {}


func _ready() -> void:
	_test_map = get_parent()
	for building in _test_map.layout.buildings():
		_spawn_building(building)
	# Construction completion rides the same once-per-day signal crop growth uses (see class doc).
	DayManager.day_started.connect(_on_day_started)


## Lit windows after dark (2026-10-07, scripts/night_light.gd): kind -> [colour, strength,
## radius scale]. Homes glow warm, the clinic and kitchen a little brighter.
const NightLight := preload("res://scripts/night_light.gd")
const WINDOW_LIGHTS := {
	"farmhouse": ["#ffc27a", 0.85, 1.25],
	"mayor_house": ["#ffc27a", 0.85, 1.4],
	"store": ["#ffd08a", 0.9, 1.25],
	"shack": ["#ffb86b", 0.65, 0.95],
	"ranch_house": ["#ffc27a", 0.8, 1.2],
	"workshop": ["#ffb86b", 0.7, 1.1],
	"clinic": ["#fff0c8", 0.9, 1.2],
	"community_kitchen": ["#ffc27a", 0.9, 1.3],
	"trading_post": ["#ffd08a", 0.8, 1.2],
	# Milestone B Town Works: Marta's rebuilt shopfront and the rebuilt clinic (the ruined clinic
	# stays dark).
	"store_expanded": ["#ffd08a", 0.95, 1.35],
	"town_clinic": ["#fff0c8", 0.95, 1.45],
}


func _spawn_building(building: Dictionary) -> void:
	var top_left: Vector2i = building["top_left"]
	var footprint_size: Vector2i = building["size"]
	var kind := String(building["kind"])
	if kind == "chest":
		_chest_cell = top_left
	elif kind == "bed":
		_bed_cell = top_left
	elif kind == "shipping_box":
		_shipping_box_cell = top_left
	elif kind == "bulletin_board":
		_board_cell = top_left
	var visual := _spawn_footprint_body(top_left, footprint_size, kind)
	var id := String(building.get("id", kind))
	_layout_visuals[id] = visual
	_layout_kinds[id] = kind


## The shared "one StaticBody2D + one visual covering the footprint" spawner — Phase 4 Stage 1's
## layout-building pattern, factored out so Stage 2's runtime blueprints reuse it verbatim.
## Phase 6 Art pass 1: the *completed* visual is now a Sprite2D textured with the kind's real
## PixelLab art when it exists (art/buildings/<kind>.png), falling back to a flat-color
## ImageTexture in the kind's BUILDING_COLORS fill — the exact "real art with graceful
## placeholder fallback" pattern farm.gd's _crop_texture() established. An under-construction
## blueprint (`blueprint = true`) still renders EXACTLY as before — a translucent
## BLUEPRINT_COLOR ColorRect — regardless of whether final art exists; only completion swaps in
## the textured sprite (see _complete_construction). Returns the visual node (CanvasItem: the
## blueprint ColorRect or the final Sprite2D) so completion can swap it in place.
##
## Phase 8 Stage 2 (fencing & perimeter system): `solid` (default true) gates whether the body
## gets a CollisionShape2D at all — false skips it entirely, so a non-solid completed structure
## (a Gate) never physically blocks the player's CharacterBody2D. Every pre-existing caller
## (layout-authored buildings, blueprint placement) leans on the true default, so nothing but
## _complete_construction's new solid=false path (see below) ever passes false.
func _spawn_footprint_body(top_left: Vector2i, footprint_size: Vector2i, kind: String,
		blueprint: bool = false, solid: bool = true) -> CanvasItem:
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
	if solid:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = px_size - Vector2(2, 2)  # 1px margin each side, matches farm.gd's resource props
		shape.shape = rect
		body.add_child(shape)

	var visual := _make_visual(kind, px_size, blueprint)
	body.add_child(visual)

	add_child(body)
	_bodies.append(body)
	return visual


## Builds the footprint's visual node. Blueprint: the Phase 4 Stage 2 translucent-blue ColorRect,
## unchanged. Final: a Sprite2D centered on the body origin (the body sits at the footprint's
## world center, and Sprite2D textures are center-anchored by default, so position stays zero).
func _make_visual(kind: String, px_size: Vector2, blueprint: bool) -> CanvasItem:
	if blueprint:
		var rect := ColorRect.new()
		rect.size = px_size - Vector2(2, 2)
		rect.position = -rect.size * 0.5
		rect.color = BLUEPRINT_COLOR
		return rect
	var sprite := Sprite2D.new()
	sprite.texture = _building_texture(kind, px_size)
	_bottom_align(sprite, px_size)
	if WINDOW_LIGHTS.has(kind):
		var spec: Array = WINDOW_LIGHTS[kind]
		var light := NightLight.make(Color(spec[0]), float(spec[1]), float(spec[2]))
		light.position = Vector2(0, px_size.y * 0.15)
		sprite.add_child(light)
	return sprite


## Art taller than its footprint (a tower, a roof) rises above it: the sprite's bottom edge sits
## on the footprint's bottom edge instead of the art being centred on the footprint.
static func _bottom_align(sprite: Sprite2D, px_size: Vector2) -> void:
	var extra := float(sprite.texture.get_height()) - px_size.y
	sprite.offset = Vector2(0, -extra / 2.0) if extra > 0.0 else Vector2.ZERO


## Real PixelLab art if the kind's file exists (art/buildings/<kind>.png — see
## art/buildings/README.md for provenance); otherwise a flat-color placeholder ImageTexture in
## the kind's BUILDING_COLORS fill (sized like the old ColorRect: footprint minus the 1px
## margin), so the game still runs — and headless tests still pass — even before/without the
## generated art present. Same shape as farm.gd's _crop_texture() and hud.gd's icon loading.
func _building_texture(kind: String, px_size: Vector2) -> Texture2D:
	var path := "res://art/buildings/%s.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.create(maxi(int(px_size.x) - 2, 1), maxi(int(px_size.y) - 2, 1),
		false, Image.FORMAT_RGBA8)
	image.fill(Color(String(BUILDING_COLORS.get(kind, "#8c8478"))))
	return ImageTexture.create_from_image(image)


## -- Phase 4 Stage 2: runtime building placement --

## Whether a footprint can be constructed here. Per cell: inside the map, plain open grass only
## (FarmGrid's tillable-terrain rule — deliberately excludes authored farmland 'f', docks, gates,
## water, fence, and former tree/ore cells, whose ASCII chars persist after clearing), not
## layout-solid or inside any building footprint (test_map.is_blocked_at, which also covers
## already-placed/pending runtime buildings via the _runtime_blocked overlay), not player-tilled,
## free of crops and standing tree/ore resource nodes, and — Phase 8 Stage 2 — not already inside
## a pending/completed structure's footprint (_is_footprint_occupied). That last check exists
## specifically for the gap a completed non-solid Gate opens: once its cell is unblocked via
## test_map.unblock_cells, is_blocked_at() alone no longer catches it, so a second building could
## otherwise be placed directly on top of a working Gate.
func can_place(top_left: Vector2i, footprint_size: Vector2i) -> bool:
	if not BuildGrid.cells_within_map(top_left, footprint_size, _test_map.layout.size()):
		return false
	var farm: Node = _test_map.get_node("Farm")
	for cell in BuildGrid.footprint_cells(top_left, footprint_size):
		if _test_map.is_blocked_at(cell) or _test_map.is_tilled_at(cell):
			return false
		if _is_footprint_occupied(cell):
			return false
		if not FarmGrid.is_tillable_terrain(String(_test_map.terrain_at(cell))):
			return false
		if not farm.get_plot(cell).is_empty():
			return false
		var objects: Node = _test_map.get_node_or_null("Objects")
		if objects != null and objects.has_object(cell):
			return false
	return true


## Phase 8 Stage 2: whether `cell` sits inside any pending or completed structure's footprint —
## the guard that closes the gap a completed non-solid Gate opens (see can_place()'s doc above).
## Same cell-range-scan style storage_inventory_at() already uses over _completed, just widened
## to _pending too (an under-construction site is already caught by test_map.is_blocked_at, but
## scanning both here keeps this one query authoritative on its own, not order-dependent on the
## caller having checked is_blocked_at first).
func _is_footprint_occupied(cell: Vector2i) -> bool:
	for entry in _pending + _completed:
		var top_left: Vector2i = entry["top_left"]
		var footprint_size: Vector2i = entry["size"]
		if cell.x >= top_left.x and cell.x < top_left.x + footprint_size.x \
				and cell.y >= top_left.y and cell.y < top_left.y + footprint_size.y:
			return true
	return false


## Place a structure blueprint: spawns the collidable under-construction body and registers its
## footprint in test_map's runtime-blocked overlay (so hoes and other blueprints can't target
## those cells while it builds). Resource/energy spending is the CALLER's job (scripts/
## builder.gd's confirm step) — this node stays inventory-agnostic, as it is for the layout chest.
func place_blueprint(building_id: String, top_left: Vector2i) -> bool:
	if not BuildingDB.has_building(building_id):
		return false
	var footprint_size := BuildingDB.size_of(building_id)
	if not can_place(top_left, footprint_size):
		return false
	var kind := BuildingDB.kind(building_id)
	var visual := _spawn_footprint_body(top_left, footprint_size, kind, true)
	_pending.append({
		"building_id": building_id,
		"kind": kind,
		"top_left": top_left,
		"size": footprint_size,
		"placed_day": DayManager.day,
		"visual": visual,
	})
	_test_map.block_cells(BuildGrid.footprint_cells(top_left, footprint_size))
	return true


func _on_day_started(day: int) -> void:
	var still_pending: Array[Dictionary] = []
	for entry in _pending:
		if BuildGrid.is_construction_complete(int(entry["placed_day"]), day,
				BuildingDB.build_days(String(entry["building_id"]))):
			_complete_construction(entry)
		else:
			still_pending.append(entry)
	_pending = still_pending
	_tick_building_yields_and_effects()
	_resolve_trading_posts()
	# Phase 5 Stage 3: the shipping box's overnight sale rides the same signal. Because signal
	# emission is synchronous, this (and the crops_sold -> player.add_credits hop main.gd wires)
	# has fully resolved before player._sleep_in_bed()'s skip_to_next_morning() call returns —
	# i.e. strictly BEFORE the GameState.save_game() at the end of that function, so the save
	# always captures the emptied box, the appended history entry, and the credited balance.
	# It fires identically on a natural midnight rollover or a pass-out, which is correct:
	# morning came either way, so "Credits added next morning" holds (Stardew's rule too).
	_resolve_shipping_sale(day)


## Phase 8 Stage 1: the generalized building-effect dispatch, run once per morning after this
## zone's pending constructions have resolved. ONE pass over _completed handles every functional
## building kind: BuildingDB.daily_yield() sums generically into one dict (a 13th yield-granting
## building needs zero new code here, only a buildings.json entry), and any completed entry whose
## BuildingDB.effect() key matches a BuildingEffects.EFFECTS callable (so far, only the Rain
## Collector) gets that callable invoked with itself + a small ctx (this zone's own Farm sibling
## — effects that need to touch farmland do so through that, never through `player`). Emits
## building_yield_produced ONCE with the accumulated total if non-empty; stays inventory-agnostic
## (never touches player directly) so main.gd owns wiring the signal to player.add_items.
func _tick_building_yields_and_effects() -> void:
	var yields := {}
	var ctx := {"farm": _test_map.get_node("Farm")}
	for entry in _completed:
		var building_id := String(entry["building_id"])
		var yield_here := BuildingDB.daily_yield(building_id)
		for item_id in yield_here:
			yields[item_id] = int(yields.get(item_id, 0)) + int(yield_here[item_id])
		var effect_key := BuildingDB.effect(building_id)
		if BuildingEffects.EFFECTS.has(effect_key):
			BuildingEffects.EFFECTS[effect_key].call(entry, ctx)
	if not yields.is_empty():
		building_yield_produced.emit(yields)


## Phase 8 Stage 1: public getter for every completed structure in this zone — main.gd gathers
## these across all 4 zones (its own _all_completed_entries() helper) for
## BuildingEffects.recompute_capacity_unlocks()/settler_arrival_modifiers(). Returns the live
## array itself, not a duplicate, matching every other read-only-by-convention getter here (e.g.
## get_plot in farm.gd) — callers must not mutate entries.
func completed_entries() -> Array[Dictionary]:
	return _completed


func _complete_construction(entry: Dictionary) -> void:
	# Phase 6 Art pass 1: completion swaps the blueprint ColorRect for the kind's final visual
	# (real texture or flat-color fallback) — originally done by swapping the visual child
	# in place on the SAME body, since every completed structure used to stay solid forever.
	#
	# Phase 8 Stage 2: a Gate (BuildingDB.solid() false) must drop its collision on completion —
	# the blueprint body was spawned solid=true unconditionally (place_blueprint()'s "a
	# construction site blocks like anything else while building" rule), so that CollisionShape2D
	# already exists on it. Rather than reach in and pull the shape back out of a live body, the
	# whole blueprint body is retired here and a fresh one spawned through the same
	# _spawn_footprint_body(..., solid) codepath every other spawn site uses — one place decides
	# whether a body gets a collision shape, not two.
	var blueprint_visual: CanvasItem = entry["visual"]
	var old_body := blueprint_visual.get_parent()
	var building_id := String(entry["building_id"])
	var top_left := Vector2i(entry["top_left"])
	var footprint_size := Vector2i(entry["size"])
	var is_solid := BuildingDB.solid(building_id)
	old_body.queue_free()
	_bodies.erase(old_body)
	var final_visual := _spawn_footprint_body(top_left, footprint_size,
		String(entry["kind"]), false, is_solid)
	entry["visual"] = final_visual
	_completed.append(entry)
	if not is_solid:
		# The footprint was blocked unconditionally at placement (place_blueprint()); a completed
		# non-solid structure (a Gate) becomes walkable by lifting that overlay now. can_place()'s
		# _is_footprint_occupied() guard (see its doc) is what stops a second building from then
		# being placed on the now-unblocked cell.
		_test_map.unblock_cells(BuildGrid.footprint_cells(top_left, footprint_size))
	if BuildingDB.is_storage(building_id) or BuildingDB.interaction(building_id) == POST_INTERACTION:
		# A trading post's shelf is a storage inventory too (Milestone D), so it saves with the rest.
		_storage_inventories[entry["top_left"]] = Inventory.new()


## The storage Inventory reachable at a cell: the layout chest's, or a completed storage
## structure's (any cell of its footprint counts, so a 2x2 shed is interactable from every side).
## null when the cell isn't storage.
func storage_inventory_at(cell: Vector2i) -> Inventory:
	if cell == _chest_cell:
		return chest_inventory
	for entry in _completed:
		var top_left: Vector2i = entry["top_left"]
		var footprint_size: Vector2i = entry["size"]
		if _storage_inventories.has(top_left) \
				and cell.x >= top_left.x and cell.x < top_left.x + footprint_size.x \
				and cell.y >= top_left.y and cell.y < top_left.y + footprint_size.y:
			return _storage_inventories[top_left]
	return null


func is_chest_at(cell: Vector2i) -> bool:
	return storage_inventory_at(cell) != null


## Called by player.gd when the player interacts (use_tool) facing a storage cell — the layout
## chest or a completed Storage Shed. Instant — no energy cost, no tool-swing lock, matching
## HUD's existing toggle_inventory ("I" key) UX rather than farming's tool-swing dispatch.
func interact_chest(cell: Vector2i) -> void:
	var inv := storage_inventory_at(cell)
	if inv != null:
		chest_toggled.emit(inv, cell)


## -- Phase 4 Stage 3: the farmhouse bed --

## Whether the cell is the layout-authored bed beside the farmhouse. player.gd checks this in
## its use_tool() priority dispatch (alongside is_chest_at) and runs the sleep sequence itself —
## sleeping touches player-owned state (energy) and the save system, so the player node owns
## the sequence the way it already owns _pass_out().
func is_bed_at(cell: Vector2i) -> bool:
	return cell == _bed_cell


## -- Phase 5 Stage 3: the shipping box --

## Whether the cell is the layout-authored shipping box. Checked by player.gd's use_tool()
## priority dispatch (alongside is_chest_at/is_bed_at); the interaction itself (the crop-loading
## UI) is scripts/shipping_ui.gd's job, reached via player.gd's shipping_box_requested signal —
## the same signal-handoff shape as NPC dialogue, since the UI needs the player's inventory.
func is_shipping_box_at(cell: Vector2i) -> bool:
	return cell == _shipping_box_cell


## -- Milestone D (2026-11-10): the trading post, the player's own shop
##    (docs/LIVING_SETTLEMENT.md §3) --
## Its shelf is a storage inventory. Each morning passing trade buys from it in shelf order at
## the markup the player set: the higher the markup, the fewer units move. A settler assigned
## as trader sells half as many again. It ignores glut and demand.

signal post_sold(total: int, sold: Dictionary)

const POST_INTERACTION := "trading_post"
const POST_NAMES: Array[String] = ["Fair", "Bold", "Steep"]
const POST_MARKUPS: Array[float] = [1.15, 1.35, 1.6]
const POST_UNITS: Array[int] = [12, 6, 3]
const POST_CLERK_BONUS := 1.5

var _post_markup: Dictionary = {}
## Callable(top_left: Vector2i) -> bool: whether a settler is assigned to that post (main.gd).
var clerk_check: Callable = Callable()


## The top-left of the completed trading post covering `cell`, or (-1, -1).
func post_at(cell: Vector2i) -> Vector2i:
	for entry in _completed:
		if BuildingDB.interaction(String(entry["building_id"])) != POST_INTERACTION:
			continue
		var top_left: Vector2i = entry["top_left"]
		var footprint_size: Vector2i = entry["size"]
		if cell.x >= top_left.x and cell.x < top_left.x + footprint_size.x \
				and cell.y >= top_left.y and cell.y < top_left.y + footprint_size.y:
			return top_left
	return Vector2i(-1, -1)


func is_trading_post_at(cell: Vector2i) -> bool:
	return post_at(cell) != Vector2i(-1, -1)


func post_markup(top_left: Vector2i) -> int:
	return int(_post_markup.get(top_left, 0))


func cycle_post_markup(top_left: Vector2i) -> int:
	_post_markup[top_left] = (post_markup(top_left) + 1) % POST_MARKUPS.size()
	return post_markup(top_left)


static func post_units(level: int, clerk: bool) -> int:
	var units := POST_UNITS[clampi(level, 0, POST_UNITS.size() - 1)]
	return int(floor(float(units) * POST_CLERK_BONUS)) if clerk else units


## "Fair: +15%, sells up to 12 a day" for the shelf screen.
static func post_summary(level: int, clerk: bool) -> String:
	var l := clampi(level, 0, POST_MARKUPS.size() - 1)
	return "%s: +%d%%, sells up to %d a day" % [POST_NAMES[l], int(round((POST_MARKUPS[l] - 1.0) * 100.0)),
		post_units(l, clerk)]


## What a day's trade takes from `slots` (an Inventory's slots) at markup `level`: shippable
## items only, in shelf order. {"sold": {item: count}, "total": Credits}.
static func post_sale(slots: Array, level: int, clerk: bool) -> Dictionary:
	var left := post_units(level, clerk)
	var markup := POST_MARKUPS[clampi(level, 0, POST_MARKUPS.size() - 1)]
	var sold := {}
	var total := 0
	for slot in slots:
		if left <= 0:
			break
		var item_id := String((slot as Dictionary).get("item_id", ""))
		var count := int((slot as Dictionary).get("count", 0))
		if item_id == "" or count <= 0 or not ShippingDB.is_shippable(item_id):
			continue
		var take := mini(count, left)
		sold[item_id] = int(sold.get(item_id, 0)) + take
		total += take * int(round(float(ShippingDB.unit_value(item_id)) * markup))
		left -= take
	return {"sold": sold, "total": total}


func _resolve_trading_posts() -> void:
	for entry in _completed:
		if BuildingDB.interaction(String(entry["building_id"])) != POST_INTERACTION:
			continue
		var top_left: Vector2i = entry["top_left"]
		var inv: Inventory = _storage_inventories.get(top_left)
		if inv == null:
			continue
		var clerk := clerk_check.is_valid() and bool(clerk_check.call(top_left))
		var result := post_sale(inv.slots, post_markup(top_left), clerk)
		if int(result["total"]) <= 0:
			continue
		for item_id in result["sold"]:
			inv.remove_item(String(item_id), int(result["sold"][item_id]))
		post_sold.emit(int(result["total"]), result["sold"])


## -- Milestone B: the notice board and Town Works --

## Whether the cell is the town square's notice board (player.gd opens the board on it).
func is_board_at(cell: Vector2i) -> bool:
	return cell == _board_cell


## The kind a layout building is currently drawn as ("" for an unknown id).
func building_kind(building_id: String) -> String:
	return String(_layout_kinds.get(building_id, ""))


## Redraws a layout building as `kind` (a finished project: the store's new shopfront, the rebuilt
## clinic). Its footprint and collision don't change; the window glow follows the new kind.
func set_building_art(building_id: String, kind: String) -> void:
	var sprite: Sprite2D = _layout_visuals.get(building_id) as Sprite2D
	if sprite == null:
		return
	# The footprint in px: the collision rect plus its 1px margin each side.
	var px_size := Vector2(sprite.texture.get_size())
	for child in sprite.get_parent().get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			px_size = ((child as CollisionShape2D).shape as RectangleShape2D).size + Vector2(2, 2)
	sprite.texture = _building_texture(kind, px_size)
	_bottom_align(sprite, px_size)
	for child in sprite.get_children():
		child.queue_free()
	if WINDOW_LIGHTS.has(kind):
		var spec: Array = WINDOW_LIGHTS[kind]
		var light := NightLight.make(Color(spec[0]), float(spec[1]), float(spec[2]))
		light.position = Vector2(0, px_size.y * 0.15)
		sprite.add_child(light)
	_layout_kinds[building_id] = kind


## Adds a Town Works building (the watchtower): a solid footprint drawn with art/buildings/<kind>.png,
## optionally with a night glow ([colour, strength, radius scale, height above the base in px]).
## Idempotent per id, so re-applying the finished projects at boot is harmless.
func add_works_building(id: String, kind: String, top_left: Vector2i, footprint_size: Vector2i,
		light: Array = []) -> void:
	if _works.has(id):
		return
	var visual := _spawn_footprint_body(top_left, footprint_size, kind)
	if not light.is_empty() and visual is Sprite2D:
		var glow := NightLight.make(Color(String(light[0])), float(light[1]), float(light[2]))
		glow.position = Vector2(0, float(footprint_size.y) * float(CELL_SIZE) / 2.0 - float(light[3]))
		visual.add_child(glow)
	_test_map.block_cells(BuildGrid.footprint_cells(top_left, footprint_size))
	_works[id] = visual
	_works_rects[id] = Rect2i(top_left, footprint_size)


func has_works_building(id: String) -> bool:
	return _works.has(id)


## Takes a Town Works building down again (Doc's tent, once the clinic is rebuilt).
func remove_works_building(id: String, top_left: Vector2i, footprint_size: Vector2i) -> void:
	var visual: Node = _works.get(id)
	if visual == null:
		return
	var body: Node = visual.get_parent()
	_bodies.erase(body)
	body.queue_free()
	_test_map.unblock_cells(BuildGrid.footprint_cells(top_left, footprint_size))
	_works.erase(id)
	_works_rects.erase(id)


## The id of the Town Works / festival building covering `cell` ("" if none). player.gd offers an
## interaction on the ones in USABLE_WORKS (Milestone D: the festival booth).
func works_id_at(cell: Vector2i) -> String:
	for id in _works_rects:
		if (_works_rects[id] as Rect2i).has_point(cell):
			return String(id)
	return ""


const USABLE_WORKS := {"festival_booth": "Join in"}


## Loads crops into the box's pending contents. Returns false (contents untouched) for a
## non-crop item or non-positive count — the item-removal from the player's inventory is the
## CALLER's job (scripts/shipping_ui.gd), and only after this returns true, so a refusal can
## never eat the item; this node stays inventory-agnostic exactly like place_blueprint().
func add_to_shipping_box(item_id: String, count: int) -> bool:
	var updated := ShippingDB.add_to_contents(shipping_contents, item_id, count)
	if updated == shipping_contents:
		return false
	shipping_contents = updated
	return true


## Sells the pending contents (if any) on the new morning `day`: appends the itemized history
## entry, clears the box, and emits crops_sold with the total for main.gd's wire to
## player.add_credits. See _on_day_started's comment for the save-ordering guarantee.
func _resolve_shipping_sale(day: int) -> void:
	if shipping_contents.is_empty():
		return
	var entry := ShippingDB.make_history_entry(day, shipping_contents)
	if market != null:
		# Milestone D: glut and demand move each item's price (scripts/market.gd); the shopfront
		# bonus rides on top. "base" keeps what it would have fetched at list price.
		var quote: Dictionary = market.sell(shipping_contents, sale_multiplier)
		entry["base"] = int(entry["total"])
		entry["total"] = int(quote["total"])
	elif sale_multiplier != 1.0:
		entry["bonus"] = int(round(float(entry["total"]) * (sale_multiplier - 1.0)))
		entry["total"] = int(entry["total"]) + int(entry["bonus"])
	sale_history.append(entry)
	shipping_contents = {}
	crops_sold.emit(int(entry["total"]))


## -- Phase 4 Stage 3: save/load (see scripts/save_data.gd's class doc for the shape) --

func save_state() -> Dictionary:
	var pending_out: Array = []
	for entry in _pending:
		pending_out.append(SaveData.encode_structure_entry(entry))
	var completed_out: Array = []
	for entry in _completed:
		completed_out.append(SaveData.encode_structure_entry(entry))
	var storage_out := {}
	for top_left in _storage_inventories:
		var inv: Inventory = _storage_inventories[top_left]
		storage_out[SaveData.cell_key(top_left)] = \
			SaveData.encode_inventory(inv.slots, inv.selected_hotbar_index)
	var posts_out := {}
	for top_left in _post_markup:
		posts_out[SaveData.cell_key(top_left)] = int(_post_markup[top_left])
	return {
		"pending": pending_out,
		"completed": completed_out,
		"storage": storage_out,
		"chest": SaveData.encode_inventory(
			chest_inventory.slots, chest_inventory.selected_hotbar_index),
		"shipping": SaveData.encode_shipping(shipping_contents, sale_history),
		"posts": posts_out,
	}


## Rebuilds runtime-placed structures from a loaded save: each entry gets its visual body
## re-spawned through the same _spawn_footprint_body() the live placement/completion paths use
## (blueprint-blue for pending, final kind art/fill for completed), and its footprint re-registered
## in test_map's _runtime_blocked overlay via the same block_cells() call place_blueprint()
## makes — re-deriving that overlay rather than serialising it, so the two can't diverge.
## Storage inventories (per-shed + the layout chest's) are restored in place.
func load_state(data: Dictionary) -> void:
	for entry_data in data.get("pending", []):
		_restore_entry(SaveData.decode_structure_entry(entry_data), true)
	for entry_data in data.get("completed", []):
		_restore_entry(SaveData.decode_structure_entry(entry_data), false)
	var storage: Dictionary = data.get("storage", {})
	for key in storage:
		var inv := Inventory.new()
		_apply_inventory_data(inv, storage[key])
		_storage_inventories[SaveData.parse_cell_key(String(key))] = inv
	_apply_inventory_data(chest_inventory, data.get("chest", {}))
	var posts: Dictionary = data.get("posts", {})
	for key in posts:
		_post_markup[SaveData.parse_cell_key(String(key))] = clampi(int(posts[key]), 0, POST_MARKUPS.size() - 1)
	# Phase 5 Stage 3: a mid-session save can hold a loaded-but-not-yet-sold box (the player
	# filled it, then saved/quit without sleeping) — restoring it here is what guarantees that
	# pending load still sells on the next morning after a reload, never silently vanishing.
	var shipping := SaveData.decode_shipping(data.get("shipping", {}))
	shipping_contents = shipping["contents"]
	sale_history = shipping["history"]


func _restore_entry(entry: Dictionary, pending: bool) -> void:
	# Phase 8 Stage 2: a pending (under-construction) entry is always solid regardless of its
	# building's final solidity (place_blueprint()'s rule); a completed entry's real solidity
	# comes straight from BuildingDB.solid(). Re-deriving this here (rather than serializing it)
	# matches _runtime_blocked's own "derive, don't serialize" doc comment on test_map.gd — and
	# for the same reason, a restored completed non-solid structure (a Gate) simply never gets
	# block_cells() called for it, which is exactly the end state the live place->complete path
	# reaches (blocked while pending, unblocked once BuildingDB.solid() is false at completion).
	var building_id := String(entry.get("building_id", ""))
	var is_solid := pending or BuildingDB.solid(building_id)
	entry["visual"] = _spawn_footprint_body(entry["top_left"], entry["size"],
		String(entry["kind"]), pending, is_solid)
	(_pending if pending else _completed).append(entry)
	if is_solid:
		_test_map.block_cells(BuildGrid.footprint_cells(entry["top_left"], entry["size"]))


func _apply_inventory_data(inv: Inventory, data: Dictionary) -> void:
	if data.is_empty():
		return
	var decoded := SaveData.decode_inventory(data)
	inv.restore(decoded["slots"], int(decoded["selected_hotbar_index"]))
