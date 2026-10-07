extends Node2D
## Root scene glue: binds the player/camera/HUD/UIs to the world (Phases 2-6 — see the wiring
## comments in _ready below), and since the zone split owns the Farm/Path/Town/Ranch zone
## cluster: all four zones stay ALWAYS-INSTANTIATED as siblings (FarmMap/PathMap/TownMap/
## RanchMap, each a test_map.tscn instance at a distinct position offset — see Finding 2 in the
## zone-transition plan: the offsets are a pure non-collision trick, never seen by the player,
## since each zone has its own clamped camera view). "Entering a zone" is a rebind + teleport
## (_bind_zone below), not a Godot scene load/unload — chosen because the zones are tiny
## (negligible memory), it avoids the cache-state-for-unloaded-zones problem entirely (every
## zone's Farm/Structures nodes always exist, so saving gathers all of them normally), and it's
## lower engineering risk. Transitions ride player.gd's gate-cell detection
## (zone_exit_requested) wrapped in scripts/zone_fade.gd's ~0.15s fade-to-black; the actual
## teleport happens at the fade's black midpoint.

const SettlementDB := preload("res://scripts/settlement_db.gd")
const ModalGate := preload("res://scripts/modal_gate.gd")
const BuildingEffects := preload("res://scripts/building_effects.gd")
const SaveData := preload("res://scripts/save_data.gd")
const StoryBeats := preload("res://scripts/story_beats.gd")

## The always-instantiated zone cluster, keyed "farm"/"path"/"town"/"ranch" — each entry
## {map, farm, structures, npcs} (the test_map.tscn instance and its leaf children). Built once
## in _ready; player.zones aliases it for the save path.
var zones: Dictionary = {}

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera
@onready var hud: CanvasLayer = $HUD
@onready var zone_fade: CanvasLayer = $ZoneFade
## Phase 8 Stage 3: the settlement-wide settler roster (scripts/settlers.gd) — a direct child of
## Main (NOT per-zone like structures/npcs), since population is a settlement-wide concept.
## settlers.gd's own _ready() reads get_parent() (this node) to reach _all_completed_entries()
## below, matching structures.gd/npcs.gd's own "get_parent() is the owning coordinator" pattern.
@onready var settlers: Node = $Settlers
@onready var animals: Node = $Animals
## Phase 7 Stage 3: the settlement-wide per-NPC relationship track (scripts/affinity.gd) — a
## direct child of Main for the same reason Settlers/Animals are: relationships belong to the
## settlement, not to whichever zone an NPC happens to stand in.
@onready var affinity: Node = $Affinity
@onready var sound_director: Node = $SoundDirector
@onready var target_cursor: Node2D = $TargetCursor

## Phase 6: the shared modal mutual-exclusion registry (see modal_gate.gd's class doc). Owned
## here — one per main scene, dying with it — and wired to every modal surface in _ready() below.
## Exposed as a plain field so the test tooling (tools/soak_test.gd) can inspect it.
var modal_gate: ModalGate = ModalGate.new()

## The build/placement-mode node, kept as a field so _process's time-pause poll below can exempt
## it from the "any modal open" check (see that poll's comment for the judgment call), and so
## _bind_zone_refs can re-point it at the active zone.
var _builder: Node2D = null


func _ready() -> void:
	for zone_id in ["farm", "path", "town", "ranch"]:
		var map: Node2D = get_node("%sMap" % String(zone_id).capitalize())
		zones[zone_id] = {
			"map": map,
			"farm": map.get_node("Farm"),
			"structures": map.get_node("Structures"),
			"npcs": map.get_node("Npcs"),
			"objects": map.get_node("Objects"),
		}
	hud.bind_player(player)
	hud.bind_inventory(player.inventory)
	Fx.register_camera(camera)
	target_cursor.bind(player)
	hud.bind_target_cursor(target_cursor)
	GameState.clear_save_sections()
	GameState.register_save_section("weather", func() -> Dictionary:
		return {"today": DayManager.weather_today, "tomorrow": DayManager.weather_tomorrow,
			"seed": DayManager.weather_seed})
	# Zone-wide signal wiring, ONCE per zone at boot (never re-run on transitions): any zone's
	# storage interaction opens the same chest UI, and any zone's shipping sale credits the same
	# player — uniform across all four zones (only the farm authors a shipping box today, but
	# wiring uniformly keeps this loop branch-free and forward-compatible).
	for zone_id in zones:
		var structures: Node = zones[zone_id]["structures"]
		structures.chest_toggled.connect(hud.toggle_chest_ui)
		structures.crops_sold.connect(player.add_credits)
		# Phase 8 Stage 1: any zone's daily building yield (Workshop's scrap, Greenhouse's
		# seedling, ...) lands in the same player inventory — the generalized-dispatch
		# counterpart of crops_sold -> player.add_credits above.
		structures.building_yield_produced.connect(player.add_items)
	# Livestock is settlement-wide. Structures are wired first and Animals is a later sibling, so
	# its day_started handler observes completed Barns/Coops before resolving production.
	animals.set_completed_entries_provider(Callable(self, "_all_completed_entries"))
	animals.animal_yield_produced.connect(player.add_items)
	# Phase 4 Stage 2: build/placement mode (scripts/builder.gd) — bound both ways, since the
	# builder reads the player's facing/inventory and the player suppresses tool swings while
	# placement mode is active. Re-bound to the active zone on every transition (_bind_zone_refs).
	var builder: Node2D = $Builder
	player.builder = builder
	_builder = builder
	# The player's zone bookkeeping: the zones dict (for _end_day/menu saves) and the
	# transition signal (fade + rebind). See player.gd's _zone_transitioning guard doc.
	player.zones = zones
	player.zone_exit_requested.connect(_on_zone_exit_requested)
	# Phase 8 Stage 3: the settlement-wide settler roster, so player.gd's _end_day()/
	# menu_screen.gd's save call site can pass it straight through to GameState.save_game().
	player.settlers = settlers
	player.animals = animals
	player.affinity = affinity
	# Phase 5 Stage 1: dialogue box (scripts/dialogue_ui.gd) — bound both ways like Builder above,
	# since player.gd needs to know a conversation is open (to freeze) and DialogueUI needs the
	# signal that says one should start.
	var dialogue_ui: Node = $DialogueUI
	player.npc_dialogue_requested.connect(dialogue_ui.open_dialogue)
	player.dialogue_ui = dialogue_ui
	# Phase 7 Stage 3: the dialogue box owns the "talk" affinity trigger and filters
	# min_affinity-gated choices, so it needs the relationship track (see dialogue_ui.gd's class
	# doc) — a plain field assignment, same shape as the modal_gate wiring further down.
	dialogue_ui.affinity = affinity
	DayManager.day_started.connect(_on_day_started)
	# Phase 8 Stage 3: a visiting settler's accept/reject choice (reached via the same dialogue
	# box every NPC uses — see dialogue_ui.gd's SETTLER_ACCEPT/REJECT sentinels) hands off to
	# settlers.resolve_visitor(), one level deeper than store_requested below, same shape.
	dialogue_ui.settler_decision_requested.connect(settlers.resolve_visitor)
	# Phase 8 Stage 4: assignment work stays settlement-wide, but farm output and wages use the
	# same player-owned inventory/Credits hooks as every other production system. These are wired
	# once at boot, never per-zone or per-transition.
	settlers.labor_yield_produced.connect(player.add_items)
	settlers.salary_charged.connect(player.add_credits)
	# Phase 5 Stage 2: Marta's store (scripts/store_ui.gd) — bound both ways like DialogueUI
	# above, one level deeper (dialogue_ui.store_requested rather than a direct player signal),
	# since the store is reached via a dialogue choice, not a direct use_tool interaction.
	var store_ui: Node = $StoreUI
	store_ui.bind(player)
	dialogue_ui.store_requested.connect(store_ui.open_store)
	player.store_ui = store_ui
	var ranch_store_ui: Node = $RanchStoreUI
	ranch_store_ui.bind(player, animals)
	dialogue_ui.ranch_store_requested.connect(_on_ranch_store_requested)
	player.ranch_store_ui = ranch_store_ui
	# Phase 5 Stage 3: the shipping box's crop-loading UI (scripts/shipping_ui.gd) — bound both
	# ways like StoreUI above, but reached directly from use_tool() facing the box. Bound to the
	# FARM zone's structures permanently: the farm is the only zone that authors a shipping box
	# (the crops_sold wire above still covers every zone uniformly).
	var shipping_ui: Node = $ShippingUI
	shipping_ui.bind(player, zones["farm"]["structures"])
	player.shipping_box_requested.connect(shipping_ui.open_box)
	player.shipping_ui = shipping_ui
	# 2026-07-12: the in-game tabbed menu (scripts/menu_screen.gd) — bound both ways like the
	# three UIs above. bind() also ADOPTS the HUD's %InventoryGrid as the menu's Inventory-tab
	# content (after bind_inventory above built its widgets), so the grid logic stays in hud.gd
	# while "toggle_inventory" now opens the full menu instead of a bare overlay.
	var menu_screen: Node = $MenuScreen
	menu_screen.bind(player, hud.inventory_grid)
	player.menu_screen = menu_screen
	# Phase 6: register every modal surface with the shared mutual-exclusion gate, so no two of
	# them can ever be open/active at once (the "B mid-conversation" input-conflict fix — see
	# modal_gate.gd's class doc, which also documents the three-line recipe for wiring in future
	# modal UIs like quest journals or pause menus — the recipe the menu above just followed).
	for surface in [builder, dialogue_ui, store_ui, ranch_store_ui, shipping_ui, menu_screen]:
		modal_gate.register(surface)
		surface.modal_gate = modal_gate
	# Phase 4 Stage 3: resuming a save vs. starting fresh. GameState stages loaded save data
	# before this scene instantiates (via the title screen's Load flow); an empty result means
	# new game -> spawn on the farm and grant the one-time settlement starting bonus instead.
	# Both paths bind unfaded — boot is not a live transition, there's nothing to mask.
	var save_data := GameState.take_pending_save()
	if save_data.is_empty():
		DayManager.reset_weather(randi())
		_bind_zone("farm")
		camera.set_target(player)
		_grant_starting_resource_bonus()
		# Phase 8 Stage 1: a fresh game starts with zero completed structures, but recomputing
		# here (rather than assuming "zero bonuses") keeps this the one call site new-game boot
		# ever needs, symmetric with _apply_save's own call below.
		_recompute_capacity_unlocks()
	else:
		_apply_save(save_data)
	_try_start_day_28_food_shortage()


## Time pauses while any TRUE modal surface is open (playtest UX gap, 2026-07-10 — Stardew's
## clock freezes during conversations and menus): DayManager's long-dormant time_paused hook,
## polled per frame from the modal gate this scene already owns. Build mode is deliberately
## EXEMPT (hence is_any_open_except(_builder), not is_any_open()): while placing, the player
## still walks the world to reposition the preview — they're not "away from the world" the way
## a conversation freezes them, and Stardew's clock likewise runs while a placement item is
## held. The HUD's inventory/chest grids are also non-pausing for the same reason: they're
## passive overlays the player can walk and act under, and frozen time under a still-actable
## player would be a free-time exploit, not a convenience.
func _process(_delta: float) -> void:
	DayManager.time_paused = modal_gate.is_any_open_except(_builder)
	# The day-start signal is the normal path. Retrying here also covers a loaded Day 28 save
	# whose scene has only just finished wiring the NPC/dialogue nodes.
	_try_start_day_28_food_shortage()


## The scene dying (quit-to-boot in the test tooling, a future title-screen return) must never
## leak a frozen clock into the next boot: DayManager is an autoload and outlives this scene,
## and if a modal happened to be open at teardown nothing would ever set time_paused back.
func _exit_tree() -> void:
	DayManager.time_paused = false
	GameState.clear_save_sections()


## -- Zone binding (the zone split's core) --

## Points every zone-scoped reference at `zone_id`'s nodes WITHOUT repositioning anything:
## the player's world refs (farm/test_map/structures/npcs), the builder's bound nodes, and the
## camera's clamp bounds. Save restoration calls only this (player.load_state already restored
## the exact saved position); live transitions and boot go through _bind_zone below.
func _bind_zone_refs(zone_id: String) -> void:
	var zone: Dictionary = zones[zone_id]
	player.current_zone_id = zone_id
	player.bind_world(zone["farm"], zone["map"], zone["structures"], zone["npcs"], zone["objects"])
	_builder.bind(player, zone["map"], zone["structures"])
	camera.set_map_bounds(zone["map"].get_global_map_rect())
	sound_director.set_zone(zone_id)


## Full zone entry: rebind refs, teleport the player to `entry_cell` (or the zone's authored
## '@' spawn when the NO_ENTRY_CELL sentinel is passed — the fresh-boot case; only the farm
## authors a spawn), snap-clamp the camera, and release player.gd's transition guard. During a
## live transition this runs as zone_fade.play()'s midpoint — while the screen is fully black —
## so the teleport/snap is invisible; the guard is therefore released while still black, and by
## fade-in the player is already standing in the new zone (see player.gd's guard doc).
const NO_ENTRY_CELL := Vector2i(-1, -1)

func _bind_zone(zone_id: String, entry_cell: Vector2i = NO_ENTRY_CELL) -> void:
	_bind_zone_refs(zone_id)
	var map: Node2D = zones[zone_id]["map"]
	if entry_cell == NO_ENTRY_CELL:
		player.global_position = map.to_global(map.get_spawn_position())
	else:
		player.global_position = map.get_global_cell_center(entry_cell)
	player.velocity = Vector2.ZERO
	camera.set_target(player)  # snap=true: instant reposition, hidden by the fade's black frame
	player.end_zone_transition()


## A gate-cell crossing (player.gd's zone_exit_requested): run the rebind/teleport at the black
## midpoint of the fade. The boot paths call _bind_zone directly, unfaded.
func _on_zone_exit_requested(target_zone: String, entry_cell: Vector2i) -> void:
	zone_fade.play(func() -> void: _bind_zone(target_zone, entry_cell))


## Restores each system's saved state (see scripts/save_data.gd's class doc for the v2 shape)
## on top of the layout-authored world the child nodes' _ready() already built. Per-zone
## sections apply to each always-instantiated zone's own nodes; the player section restores the
## exact saved position/zone, so only _bind_zone_refs (no teleport, no fade) follows it.
## DayManager fields are assigned directly — no day_started emission, since re-loading a day
## must not re-run daily ticks (crop growth already happened before the save was written).
func _apply_save(data: Dictionary) -> void:
	DayManager.day = int(data.get("day", 1))
	DayManager.minutes_into_day = float(data.get("minutes_into_day", DayManager.DAY_START_MINUTES))
	var weather: Dictionary = data.get("weather", {})
	if weather.is_empty():
		DayManager.reset_weather(hash([data.get("settlement_id", ""), data.get("saved_unix", 0)]))
	else:
		DayManager.weather_seed = int(weather.get("seed", 0))
		DayManager.weather_today = String(weather.get("today", "clear"))
		DayManager.weather_tomorrow = String(weather.get("tomorrow", "clear"))
	var zones_data: Dictionary = data.get("zones", {})
	for zone_id in zones:
		var zone_data: Dictionary = zones_data.get(zone_id, {})
		zones[zone_id]["map"].load_state(zone_data.get("map", {}))
		var farm_data: Dictionary = zone_data.get("farm", {})
		zones[zone_id]["farm"].load_state(farm_data)
		zones[zone_id]["structures"].load_state(zone_data.get("structures", {}))
		# Pre-world-objects saves kept trees/ore as the farm section's "resource_nodes".
		var legacy = null
		if farm_data.has("resource_nodes"):
			legacy = SaveData.decode_resource_nodes(farm_data.get("resource_nodes", {}))
		zones[zone_id]["objects"].load_state(zone_data.get("objects", {}), legacy)
	player.load_state(data.get("player", {}))
	# Phase 8 Stage 3: restores roster/pending-visitor state and re-spawns each as a real NPC in
	# Town, re-registering their runtime dialogue trees — AFTER the zone loop above (Town's Npcs
	# node already exists from _ready(), but its own load_state() above touches no NPC state; see
	# npc.gd's class doc for why NPC position itself is never persisted). Must run before
	# _recompute_capacity_unlocks() below reads a population cap this roster is checked against.
	settlers.load_state(data.get("settlers", {}))
	animals.load_state(SaveData.decode_animals(data.get("animals", {})))
	# Phase 7 Stage 3: additive "affinity" section — an old save with no such key restores an
	# empty relationship track (see affinity.gd's load_state), never an error.
	affinity.load_state(data.get("affinity", {}))
	var story_flags: Dictionary = SaveData.decode_story_flags(data.get("story_flags", {}))
	GameState.day_28_food_shortage_seen = bool(story_flags["day_28_food_shortage_seen"])
	_bind_zone_refs(player.current_zone_id)
	camera.set_target(player)
	# Phase 8 Stage 1: re-derive capacity bonuses from the JUST-RESTORED structures rather than
	# trusting anything saved about them — same "recomputed in full, never incrementally
	# serialized" rule BuildingEffects.recompute_capacity_unlocks documents.
	_recompute_capacity_unlocks()


## Phase 8 Stage 1: every completed structure across all 4 always-instantiated zones, flattened
## into one Array — the exact shape BuildingEffects.recompute_capacity_unlocks()/
## settler_arrival_modifiers() expect. The one place that knows "all 4 zones" for this purpose,
## so later stages (Stage 3's arrival roll) can reuse it rather than re-deriving their own loop.
func _all_completed_entries() -> Array:
	var out: Array = []
	for zone_id in zones:
		var structures: Node = zones[zone_id]["structures"]
		out.append_array(structures.completed_entries())
	return out


## Re-derives every completed structure's one-time capacity bonuses from scratch
## (BuildingEffects.recompute_capacity_unlocks) and applies them: player.max_energy off
## player.BASE_MAX_ENERGY, and the builder's build-cost energy discount — so a live completion,
## a reload, or (Stage 3) an accepted settler's population cap can never drift from the actual
## count of completed Clinics/Solar Panels/Shelter Cabins. Called once for a fresh game (_ready,
## above) and once after restoring a save (_apply_save, above).
func _recompute_capacity_unlocks() -> void:
	var bonuses := BuildingEffects.recompute_capacity_unlocks(_all_completed_entries())
	player.max_energy = player.BASE_MAX_ENERGY + float(bonuses.get("energy_max", 0))
	player.energy = minf(player.energy, player.max_energy)
	player.energy_changed.emit(player.energy, player.max_energy)
	_builder.build_energy_discount = clampf(float(bonuses.get("build_energy_discount", 0.0)), 0.0, 1.0)


func _on_day_started(_day: int) -> void:
	_try_start_day_28_food_shortage()


func _on_ranch_store_requested(target_npc: Node) -> void:
	# Preserve Silas's authored "build one first" branch until a completed Barn/Coop exists;
	# pending construction must not count as usable capacity.
	if animals.capacity_for("barn") + animals.capacity_for("coop") <= 0:
		$DialogueUI.open_dialogue_at(target_npc, "not_yet")
		return
	$RanchStoreUI.open_ranch(target_npc)


func _try_start_day_28_food_shortage() -> void:
	if not StoryBeats.should_trigger_day_28_food_shortage(
			DayManager.day, GameState.day_28_food_shortage_seen):
		return
	var town: Dictionary = zones.get("town", {})
	var town_npcs: Node = town.get("npcs")
	if town_npcs == null:
		return
	var harlan: Node = null
	for npc in town_npcs.npcs():
		if String(npc.npc_id) == StoryBeats.DAY_28_FOOD_SHORTAGE_NPC_ID:
			harlan = npc
			break
	if harlan == null:
		return
	var dialogue_ui: Node = $DialogueUI
	if dialogue_ui.open_dialogue_at(harlan, StoryBeats.DAY_28_FOOD_SHORTAGE_NODE_ID):
		GameState.day_28_food_shortage_seen = true


## The chosen settlement's resource-lean bonus (water access / ruin materials / better soil —
## see settlement_db.gd's SETTLEMENTS data), granted once on top of player.gd's fixed starting
## loadout (tools + potato seeds), matching ROADMAP.md Phase 4's "differing starting resources"
## checklist item.
func _grant_starting_resource_bonus() -> void:
	for entry in SettlementDB.starting_items(GameState.chosen_settlement_id):
		player.inventory.add_item(String(entry.get("item_id", "")), int(entry.get("count", 0)))
