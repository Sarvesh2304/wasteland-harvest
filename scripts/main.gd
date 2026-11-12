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
const StorageUIScript := preload("res://scripts/storage_ui.gd")
const BuildingEffects := preload("res://scripts/building_effects.gd")
const SaveData := preload("res://scripts/save_data.gd")
const StoryBeats := preload("res://scripts/story_beats.gd")
const ExpeditionScript := preload("res://scripts/expedition.gd")
const ConfirmUIScript := preload("res://scripts/confirm_ui.gd")
const EnemiesScript := preload("res://scripts/enemies.gd")
const MapScene := preload("res://scenes/test_map.tscn")
const LoreDB := preload("res://scripts/lore_db.gd")
const QuestsScript := preload("res://scripts/quests.gd")
const QuestDB := preload("res://scripts/quest_db.gd")
const TownWorksScript := preload("res://scripts/town_works.gd")
const NoticeUIScript := preload("res://scripts/notice_ui.gd")
const MarketScript := preload("res://scripts/market.gd")
const CaravanScript := preload("res://scripts/caravan.gd")
const FestivalsScript := preload("res://scripts/festivals.gd")
const StoryScript := preload("res://scripts/story.gd")
const QuestDBRef := preload("res://scripts/quest_db.gd")
const Faction := preload("res://scripts/faction.gd")
const Weather := preload("res://scripts/weather.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")

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
## Milestone B (2026-10-07): the player's five skills (scripts/skills.gd), saved as "skills".
@onready var skills: Node = $Skills
@onready var sound_director: Node = $SoundDirector
@onready var target_cursor: Node2D = $TargetCursor

## Phase 6: the shared modal mutual-exclusion registry (see modal_gate.gd's class doc). Owned
## here — one per main scene, dying with it — and wired to every modal surface in _ready() below.
## Exposed as a plain field so the test tooling (tools/soak_test.gd) can inspect it.
var modal_gate: ModalGate = ModalGate.new()
## Milestone B: the chest/storage screen (scripts/storage_ui.gd), built in code.
var storage_ui: CanvasLayer = null
## Milestone C: the ruins zone, built in code: {map, farm, structures, npcs, objects, enemies}.
## Deliberately NOT in `zones`: every expedition regenerates it, so it's never saved.
var ruins: Dictionary = {}
var expedition: Node = null
## Milestone C: the yes/no prompt (ride out, go deeper, head home) and the lore-note reader.
var confirm_ui: CanvasLayer = null
## Milestone B (2026-10-08, docs/SOCIAL_AND_QUESTS.md): the notice board's state (requests, Town
## Works), what finished projects change in the world, and the board's screen.
var quests: Node = null
var town_works: Node = null
var notice_ui: CanvasLayer = null
## Milestone D (2026-11-10, docs/LIVING_SETTLEMENT.md): prices that move, and Tully's caravan.
var market: Node = null
var caravan: Node = null
var festivals: Node = null
var story: Node = null
## Morning notices waiting for the screen to be free ([title, body]): finished Town Works.
var _notices: Array = []

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
	_build_ruins_zone()
	hud.bind_player(player)
	hud.bind_inventory(player.inventory)
	Fx.register_camera(camera)
	target_cursor.bind(player)
	hud.bind_target_cursor(target_cursor)
	GameState.clear_save_sections()
	GameState.register_save_section("skills", func() -> Dictionary: return skills.save_state())
	GameState.register_save_section("expedition", func() -> Dictionary: return expedition.save_state())
	GameState.register_save_section("weather", func() -> Dictionary:
		return {"today": DayManager.weather_today, "tomorrow": DayManager.weather_tomorrow,
			"seed": DayManager.weather_seed})
	# Zone-wide signal wiring, ONCE per zone at boot (never re-run on transitions): any zone's
	# storage interaction opens the same chest UI, and any zone's shipping sale credits the same
	# player — uniform across all four zones (only the farm authors a shipping box today, but
	# wiring uniformly keeps this loop branch-free and forward-compatible).
	storage_ui = StorageUIScript.new()
	storage_ui.name = "StorageUI"
	add_child(storage_ui)
	storage_ui.bind(player)
	player.storage_ui = storage_ui
	for zone_id in zones:
		var structures: Node = zones[zone_id]["structures"]
		# Milestone B: every storage (the layout chest, built sheds, crafted chests) opens the
		# two-pane storage screen, which can move items in and out.
		structures.chest_toggled.connect(func(inv, cell: Vector2i) -> void:
			# Milestone D: a trading post's shelf opens with its markup controls.
			if structures.is_trading_post_at(cell):
				storage_ui.open_post(inv, cell, structures, structures.post_at(cell))
			else:
				storage_ui.open_storage(inv, cell, "Storage"))
		structures.post_sold.connect(_on_post_sold)
		var post_zone := String(zone_id)
		structures.clerk_check = func(top_left: Vector2i) -> bool:
			return settlers._assigned_count({"zone_id": post_zone, "building_id": "trading_post",
				"top_left": top_left}) > 0
		zones[zone_id]["objects"].storage_opened.connect(func(inv, cell: Vector2i) -> void:
			storage_ui.open_storage(inv, cell, "Crate Chest"))
		structures.crops_sold.connect(player.add_credits)
		# Phase 8 Stage 1: any zone's daily building yield (Workshop's scrap, Greenhouse's
		# seedling, ...) lands in the same player inventory — the generalized-dispatch
		# counterpart of crops_sold -> player.add_credits above.
		structures.building_yield_produced.connect(player.add_items)
		zones[zone_id]["objects"].vehicle_used.connect(_on_vehicle_used)
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
	player.skills = skills
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
	# Milestone B: requests, Town Works and the social layer of conversations (daily lines, gifts,
	# handing in requests, Doc's clinic).
	quests = QuestsScript.new()
	quests.name = "Quests"
	add_child(quests)
	quests.affinity = affinity
	quests.request_completed.connect(_on_request_completed)
	quests.request_expired.connect(_on_request_expired)
	quests.changed.connect(_refresh_npc_markers)
	GameState.register_save_section("quests", func() -> Dictionary: return quests.save_state())
	ruins["enemies"].enemy_killed.connect(func(enemy_type: String) -> void:
		quests.on_enemy_killed(enemy_type, player))
	market = MarketScript.new()
	market.name = "Market"
	add_child(market)
	GameState.register_save_section("market", func() -> Dictionary: return market.save_state())
	for zone_id in zones:
		zones[zone_id]["structures"].market = market
	caravan = CaravanScript.new()
	caravan.name = "Caravan"
	add_child(caravan)
	caravan.setup(zones["town"]["npcs"], zones["town"]["map"].get_node("Props"))
	GameState.register_save_section("caravan", func() -> Dictionary: return caravan.save_state())
	dialogue_ui.caravan_requested.connect(_on_caravan_requested)
	festivals = FestivalsScript.new()
	festivals.name = "Festivals"
	add_child(festivals)
	festivals.setup(self)
	GameState.register_save_section("festivals", func() -> Dictionary: return festivals.save_state())
	dialogue_ui.circle_check = Callable(festivals, "is_circle_gift")
	story = StoryScript.new()
	story.name = "Story"
	add_child(story)
	story.setup(self)
	GameState.register_save_section("story", func() -> Dictionary: return story.save_state())
	dialogue_ui.story_hook = Callable(story, "conversation_for")
	dialogue_ui.story_opened.connect(story.on_opened)
	dialogue_ui.story_choice.connect(story.on_choice)
	town_works = TownWorksScript.new()
	town_works.name = "TownWorks"
	add_child(town_works)
	town_works.setup(zones, quests)
	dialogue_ui.player = player
	dialogue_ui.context_provider = Callable(self, "dialogue_context")
	dialogue_ui.delivery_hook = func(npc_id: String) -> Dictionary: return quests.try_deliver(npc_id, player)
	dialogue_ui.gift_reacted.connect(_on_gift_reacted)
	dialogue_ui.gift_refused.connect(_on_gift_refused)
	dialogue_ui.clinic_heal_requested.connect(_on_clinic_heal)
	dialogue_ui.clinic_store_requested.connect(_on_clinic_store)
	notice_ui = NoticeUIScript.new()
	notice_ui.name = "NoticeUI"
	add_child(notice_ui)
	notice_ui.bind(player, quests)
	notice_ui.market = market
	notice_ui.caravan = caravan
	player.notice_ui = notice_ui
	player.notice_board_requested.connect(notice_ui.open)
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
	menu_screen.skills = skills
	menu_screen.quests = quests
	menu_screen.market = market
	menu_screen.caravan = caravan
	menu_screen.festivals = festivals
	menu_screen.story = story
	menu_screen.expedition = expedition
	player.menu_screen = menu_screen
	# Phase 6: register every modal surface with the shared mutual-exclusion gate, so no two of
	# them can ever be open/active at once (the "B mid-conversation" input-conflict fix — see
	# modal_gate.gd's class doc, which also documents the three-line recipe for wiring in future
	# modal UIs like quest journals or pause menus — the recipe the menu above just followed).
	for surface in [builder, dialogue_ui, store_ui, ranch_store_ui, shipping_ui, menu_screen,
			storage_ui, confirm_ui, notice_ui]:
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
		quests.new_game(randi(), DayManager.day, DayManager.season())
		market.new_game(randi())
		caravan.base_seed = randi()
		festivals.base_seed = randi()
	else:
		_apply_save(save_data)
	# Milestone E: the look chosen at character creation (or restored from the save's "profile"
	# section by GameState.load_save_from_disk) — same call for both paths.
	player.apply_appearance(GameState.player_appearance)
	caravan.on_day_started(DayManager.day, DayManager.season(), affinity.value_for(CaravanScript.NPC_ID))
	festivals.on_day_started(DayManager.day, false)
	town_works.apply()
	_refresh_npc_markers()
	_ensure_home_truck()
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
	# Morning notices (finished Town Works) wait for a free screen, e.g. after Harlan's Day-28 talk.
	if not _notices.is_empty() and not modal_gate.is_any_open() and not player.dead:
		var notice: Array = _notices.pop_front()
		confirm_ui.show_text(String(notice[0]), String(notice[1]))
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
	var zone: Dictionary = _zone(zone_id)
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
	var map: Node2D = _zone(zone_id)["map"]
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
	skills.load_state(data.get("skills", {}))
	expedition.load_state(data.get("expedition", {}))
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
	# Milestone B: the notice board. A save from before has none: start the board fresh. Then catch
	# the board up to the loaded morning (idempotent for a day it has already seen).
	var quest_data: Dictionary = data.get("quests", {})
	if quest_data.is_empty():
		quests.new_game(hash([data.get("settlement_id", ""), data.get("saved_unix", 0), "board"]),
			DayManager.day, DayManager.season())
	else:
		quests.load_state(quest_data)
	quests.on_day_started(DayManager.day, DayManager.season(), expedition.runs, expedition.max_depth)
	# Milestone D: a save from before has no market or caravan: both start fresh.
	var market_data: Dictionary = data.get("market", {})
	if market_data.is_empty():
		market.new_game(hash([data.get("settlement_id", ""), data.get("saved_unix", 0), "market"]))
	else:
		market.load_state(market_data)
	var caravan_data: Dictionary = data.get("caravan", {})
	if caravan_data.is_empty():
		caravan.base_seed = hash([data.get("settlement_id", ""), data.get("saved_unix", 0), "caravan"])
	else:
		caravan.load_state(caravan_data)
	var festival_data: Dictionary = data.get("festivals", {})
	if festival_data.is_empty():
		festivals.base_seed = hash([data.get("settlement_id", ""), data.get("saved_unix", 0), "festivals"])
	else:
		festivals.load_state(festival_data)
	story.load_state(data.get("story", {}))
	story.apply_effects()
	var story_flags: Dictionary = SaveData.decode_story_flags(data.get("story_flags", {}))
	GameState.day_28_food_shortage_seen = bool(story_flags["day_28_food_shortage_seen"])
	if not zones.has(player.current_zone_id):
		# Never resume inside a generated zone (the ruins aren't saved): wake by Kael's truck.
		player.current_zone_id = ExpeditionScript.HOME_TRUCK_ZONE
		player.global_position = zones[ExpeditionScript.HOME_TRUCK_ZONE]["map"].get_global_cell_center(
			ExpeditionScript.HOME_RETURN_CELL)
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


func _on_day_started(day: int) -> void:
	_try_start_day_28_food_shortage()
	var done: Array[String] = quests.on_day_started(day, DayManager.season(), expedition.runs, expedition.max_depth)
	if not done.is_empty():
		town_works.apply()
		Audio.play_sfx("build_complete", -2.0)
	for id in done:
		var project := QuestDB.project(id)
		_notices.append([String(project.get("name", id)),
			"%s\n\n%s" % [String(project.get("done", "")), String(project.get("reward", ""))]])
	Events.message.emit("Kael's weather call for tomorrow: %s." % Weather.display_name(DayManager.weather_tomorrow))
	# Milestone D: the market moves, and Tully comes and goes.
	if market.on_day_started(day, DayManager.season()) and not market.demand.is_empty():
		Events.message.emit("Marta's buying this week: %s." % _item_list(market.demand))
	caravan.on_day_started(day, DayManager.season(), affinity.value_for(CaravanScript.NPC_ID))
	if caravan.is_here(day):
		Events.message.emit("Tully's caravan is at the market stall today.")
	festivals.on_day_started(day)
	for notice in story.on_day_started(day):
		_notices.append(notice)


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


## -- Milestone C: the ruins and the expedition loop --

## The zone entry for `zone_id`: one of the four settlement zones, or the ruins.
func _zone(zone_id: String) -> Dictionary:
	if zone_id == "ruins":
		return ruins
	return zones[zone_id]


## Builds the ruins zone (a fifth test_map.tscn, offset well clear of the settlement zones), its
## enemy director, the expedition controller and the prompt.
func _build_ruins_zone() -> void:
	var map: Node2D = MapScene.instantiate()
	map.name = "RuinsMap"
	map.zone_id = "ruins"
	map.position = Vector2(0, 4096)
	add_child(map)
	move_child(map, get_node("RanchMap").get_index() + 1)
	var director: Node2D = EnemiesScript.new()
	director.name = "Enemies"
	map.add_child(director)
	director.setup(map, map.get_node("Objects"), player)
	ruins = {"map": map, "farm": map.get_node("Farm"), "structures": map.get_node("Structures"),
		"npcs": map.get_node("Npcs"), "objects": map.get_node("Objects"), "enemies": director}
	confirm_ui = ConfirmUIScript.new()
	confirm_ui.name = "ConfirmUI"
	add_child(confirm_ui)
	player.confirm_ui = confirm_ui
	expedition = ExpeditionScript.new()
	expedition.name = "Expedition"
	add_child(expedition)
	expedition.bind(self, player, map, ruins["objects"], director)
	expedition.level_entered.connect(_on_level_entered)
	expedition.ended.connect(_on_expedition_ended)
	hud.expedition = expedition
	hud.truck_position = func() -> Variant:
		if not expedition.active or not expedition.level.has("truck"):
			return null
		return map.get_global_cell_center(Vector2i(expedition.level["truck"])) + Vector2(16, 0)
	director.combat_changed.connect(func(active: bool) -> void:
		sound_director.set_override("combat" if active else ""))
	ruins["objects"].vehicle_used.connect(_on_vehicle_used)
	ruins["objects"].descent_used.connect(_on_descent_used)
	player.died.connect(_on_player_died)
	player.note_read_requested.connect(_read_note)


## Kael's truck parks at the path zone's north checkpoint; older saves predate it.
func _ensure_home_truck() -> void:
	var objects: Node = zones[ExpeditionScript.HOME_TRUCK_ZONE]["objects"]
	if objects.count_kinds(["kaels_truck"]) == 0:
		objects.add_generated("kaels_truck", ExpeditionScript.HOME_TRUCK_ANCHOR)


## Called by the expedition (inside the fade) once a level is built: put the player in it.
func enter_ruins(entry_cell: Vector2i) -> void:
	_bind_zone("ruins", entry_cell)
	player.facing = "south"
	if expedition.depth >= 3:
		sound_director.set_zone("ruins_deep")


## Called by the expedition (inside the fade): back to `zone_id` at `cell`.
func leave_ruins(zone_id: String, cell: Vector2i) -> void:
	sound_director.set_override("")
	_bind_zone(zone_id, cell)


func _on_vehicle_used(zone: String) -> void:
	if zone == "ruins":
		var n := ExpeditionScript.ledger_total(expedition.ledger)
		confirm_ui.ask("Head home?", "Kael's engine is running. You're carrying %d %s you found out here."
				% [n, "thing" if n == 1 else "things"], ["Head home", "Keep looking"],
			func(choice: int) -> void:
				if choice == 0:
					player.begin_zone_transition()
					zone_fade.play(expedition.extract))
		return
	if DayManager.minutes_into_day >= 22.0 * 60.0:
		confirm_ui.show_text("Too late", "Kael shakes his head. \"Not at this hour. Come back in the morning.\"")
		return
	# Milestone B: with the watchtower rebuilt, Kael drives straight to any district reached.
	if quests.is_finished("watchtower") and expedition.max_depth >= 2:
		var districts: Array = []
		for d in range(1, expedition.max_depth + 1):
			districts.append(ExpeditionScript.district_name(d))
		districts.append("Not yet")
		confirm_ui.ask("Ride out with Kael?", "Brask has the roads marked from the watchtower. Kael can drop you anywhere you've been. Where to?",
			districts, func(choice: int) -> void:
				if choice < districts.size() - 1:
					player.begin_zone_transition()
					zone_fade.play(func() -> void: expedition.depart(choice + 1)))
		return
	confirm_ui.ask("Ride out with Kael?", "Kael can run you out to the ruined city. What you scavenge is yours if you make it back to the truck. Go down out there and you lose it all.",
		["Ride out", "Not yet"], func(choice: int) -> void:
			if choice == 0:
				player.begin_zone_transition()
				zone_fade.play(expedition.depart))


func _on_descent_used() -> void:
	var next: int = expedition.depth + 1
	confirm_ui.ask("Go deeper?", "Down the stairs: %s. Meaner things, hotter air, better salvage. Kael will meet you there."
			% ExpeditionScript.district_name(next), ["Go deeper", "Stay"],
		func(choice: int) -> void:
			if choice == 0:
				player.begin_zone_transition()
				zone_fade.play(expedition.descend))


func _on_level_entered(depth: int, level_name: String) -> void:
	hud.show_banner(level_name, "Depth %d" % depth)
	if expedition.runs == 1 and depth == 1:
		Events.message.emit("Swing with Space or left-click. When something winds up, step back.")
	elif depth == 3 and expedition.max_depth == 3:
		Events.message.emit("The air tastes of metal down here. Watch your rads.")


func _on_expedition_ended(success: bool, summary: Dictionary) -> void:
	if success:
		Events.message.emit("Home safe: %d things scavenged, %d kills." % [int(summary["items"]), int(summary["kills"])])


## Went down in the ruins (or collapsed at 2 AM out there): a beat on the ground, then Kael
## carries you home. You wake the next morning at 10% HP, without anything found out there.
func _on_player_died() -> void:
	if not expedition.active:
		player.revive(maxf(1.0, player.effective_max_hp() * ExpeditionScript.DEATH_HP_FRACTION))
		return
	Audio.play_stinger("stinger_death", -2.0)
	hud.show_banner("You went down...", "Everything goes dark")
	player.begin_zone_transition()
	get_tree().create_timer(1.6).timeout.connect(func() -> void: zone_fade.play(_carry_home))


func _carry_home() -> void:
	hud.hide_banner()
	var summary: Dictionary = expedition.fail()
	sound_director.set_override("")
	_bind_zone("farm")
	player.revive(maxf(1.0, player.effective_max_hp() * ExpeditionScript.DEATH_HP_FRACTION))
	player.end_day(false)
	var lost: Dictionary = summary.get("lost", {})
	var lost_n := ExpeditionScript.ledger_total(lost)
	var body := "Kael found you face-down in the rubble and drove you home. You slept through to morning."
	if lost_n > 0:
		body += " Everything you scavenged out there (%d %s) is gone." % [lost_n, "thing" if lost_n == 1 else "things"]
	confirm_ui.show_text("You wake up at home", body)


## Reads a lore note from the pack: the next unread note this player has earned (by the
## deepest district reached), in the reader panel. A blueprint teaches a recipe instead.
func _read_note(item_id: String = "lore_note") -> void:
	if item_id == "blueprint":
		_read_blueprint()
		return
	if player.inventory.count_of("lore_note") <= 0:
		return
	var note := LoreDB.next_unread(expedition.notes_read, maxi(expedition.max_depth, 1))
	if note.is_empty():
		confirm_ui.show_text("A scrap of paper", "Too water-stained to read. Whatever it said is gone.")
		player.inventory.remove_item("lore_note", 1)
		return
	if confirm_ui.show_text(String(note.get("title", "A note")), String(note.get("text", ""))):
		player.inventory.remove_item("lore_note", 1)
		expedition.notes_read.append(String(note.get("id", "")))
		Audio.play_sfx("ui_open", -4.0)


## A pre-war blueprint teaches one recipe the player doesn't know yet (random among those
## left); once every blueprint is known, it's still worth some Crafting XP.
func _read_blueprint() -> void:
	if player.inventory.count_of("blueprint") <= 0:
		return
	var recipe_db: GDScript = load("res://scripts/recipe_db.gd")
	var unknown: Array = []
	for id in recipe_db.call("blueprint_recipes"):
		if not skills.knows_blueprint(String(id)):
			unknown.append(String(id))
	var title := "Pre-war plans"
	var body := ""
	if unknown.is_empty():
		body = "Plans for things you already know how to build. You study them anyway and pick up a trick or two."
		Events.xp_gained.emit("crafting", 25)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([DayManager.day, skills.blueprints.size(), GameState.chosen_settlement_id])
		var id: String = unknown[rng.randi_range(0, unknown.size() - 1)]
		skills.learn_blueprint(id)
		var item_name := String(load("res://scripts/item_db.gd").call("display_name", recipe_db.call("result_item", id)))
		title = "Blueprint: " + item_name
		body = "Faded pre-war plans, still readable. You can craft the %s now (menu, CRAFT tab, %s)." \
			% [item_name, String(recipe_db.call("category", id))]
		Events.xp_gained.emit("crafting", 10)
	if confirm_ui.show_text(title, body):
		player.inventory.remove_item("blueprint", 1)
		Audio.play_sfx("achievement", -4.0)


## -- Milestone D: the economy (docs/LIVING_SETTLEMENT.md) --

## "Mutant Potatoes, Berry Jam and Glowcaps".
static func _item_list(ids: Array) -> String:
	var names: Array[String] = []
	for id in ids:
		names.append(QuestDBRef.amount_text(String(id), 2).substr(2))
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


func _on_post_sold(total: int, sold: Dictionary) -> void:
	var units := 0
	for item_id in sold:
		units += int(sold[item_id])
	player.add_credits(total)
	Events.message.emit("Your trading post sold %d %s: +%d Cr." % [units, "thing" if units == 1 else "things", total])


## Tully's stall: today's stock at his prices, less 2% a heart.
func _on_caravan_requested(npc: Node) -> void:
	var hearts: int = affinity.value_for(CaravanScript.NPC_ID)
	var stock: Array = []
	var offers := {}
	for offer in caravan.offers:
		stock.append(String(offer["item"]))
		offers[String(offer["item"])] = {"price": CaravanScript.price_after(int(offer["price"]), hearts),
			"qty": int(offer["qty"])}
	$StoreUI.open_store(npc, stock, "TULLY'S CARAVAN", offers, func(item_id: String) -> void: caravan.take(item_id))


## -- Milestone B: the social layer (docs/SOCIAL_AND_QUESTS.md) --

const GIFT_FLOATS := {
	"loved": ["Loved it!", "#ff8a8a"], "liked": ["Liked it", "#ffd27f"],
	"neutral": ["Thanks", "#ffedb1"], "disliked": ["Not keen", "#c9b27a"], "hated": ["Hated it", "#9d9180"],
}


## The world flags daily lines match against (the spec's flag table); dialogue_ui.gd adds the
## season, weather, time, weekday, tier and the NPC's birthday.
func dialogue_context() -> Dictionary:
	var day: int = DayManager.day
	var flags: Dictionary = quests.flags(day)
	if day <= 7:
		flags["first_week"] = true
	if GameState.day_28_food_shortage_seen:
		flags["after_day_28"] = true
	if expedition.last_run_day >= 0 and day - expedition.last_run_day <= 1:
		flags["expedition_today"] = true
	if expedition.last_death_day >= 0 and day - expedition.last_death_day <= 2:
		flags["died_recently"] = true
	if expedition.runs >= 5:
		flags["veteran"] = true
	for step in [[2, "reached_downtown"], [3, "reached_industrial"], [4, "reached_core"]]:
		if expedition.max_depth >= int(step[0]):
			flags[String(step[1])] = true
	match Faction.standing(expedition.raider_rep):
		"Hostile":
			flags["raiders_hostile"] = true
		"Trusted":
			flags["raiders_trusted"] = true
	if player.hp < 0.4 * player.effective_max_hp():
		flags["player_hurt"] = true
	if player.rads >= 100.0:
		flags["player_irradiated"] = true
	if int(player.credits) >= 3000:
		flags["rich"] = true
	if animals.animal_count() > 0:
		flags["has_animals"] = true
	if not settlers.roster.is_empty():
		flags["has_settlers"] = true
	if caravan.is_here(day):
		flags["caravan_day"] = true
	flags.merge(festivals.flags(day))
	flags.merge(story.flags())
	return {"flags": flags}


func _on_gift_reacted(npc: Node, _item_id: String, reaction: String) -> void:
	var spec: Array = GIFT_FLOATS.get(reaction, GIFT_FLOATS["neutral"])
	Fx.float_text(npc.global_position + Vector2(0, -26), String(spec[0]), Color(String(spec[1])))
	Audio.play_sfx("achievement" if reaction == "loved" else "ui_confirm", -6.0)


func _on_gift_refused(npc: Node, reason: String) -> void:
	var name := DialogueDB.display_name(String(npc.npc_id))
	if reason == "today":
		Events.message.emit("You've already given %s a gift today." % name)
	else:
		Events.message.emit("%s has had two gifts from you this week." % name)


## Doc Ama's "patch me up" (after the clinic is rebuilt): full health and no rads, for a fee.
func _on_clinic_heal(_npc: Node) -> void:
	var price := TownWorksScript.CLINIC_HEAL_PRICE
	if player.hp >= player.effective_max_hp() - 0.5 and player.rads < 1.0:
		Events.message.emit("Doc looks you over. \"Nothing to fix. Go on, then.\"")
		return
	if int(player.credits) < price:
		Events.message.emit("Doc: \"It's %d Credits, love. Come back when you have it.\"" % price)
		return
	player.set_credits(int(player.credits) - price)
	player.set_rads(0.0)
	player.set_hp(player.effective_max_hp())
	Audio.play_sfx("drink", -4.0)
	Events.message.emit("Doc patched you up. (-%d Cr)" % price)


func _on_clinic_store(npc: Node) -> void:
	$StoreUI.open_store(npc, TownWorksScript.CLINIC_STOCK, "DOC'S SHELF")


func _on_request_completed(req: Dictionary, reward: int, thanks: String) -> void:
	Audio.play_sfx("coins", -2.0)
	Events.message.emit("Request done: %s (+%d Cr)" % [QuestDB.title_of(req), reward])
	if String(req.get("kind", "")) == "hunt":
		# Out in the ruins there's no one to thank you in person; their word reaches you anyway.
		Events.message.emit("%s: \"%s\"" % [DialogueDB.display_name(String(req.get("npc", ""))), thanks])


func _on_request_expired(req: Dictionary) -> void:
	Events.message.emit("Request expired: %s" % QuestDB.title_of(req))


## The "!" over whoever is waiting on the request you hold.
func _refresh_npc_markers() -> void:
	for zone_id in zones:
		for npc in zones[zone_id]["npcs"].npcs():
			if npc.has_method("set_quest_marker"):
				npc.set_quest_marker(quests.is_requester(String(npc.npc_id))
					or (story != null and story.wants_talk(String(npc.npc_id))))

