extends Node2D
## Root scene glue: spawns the player on the active map (scripts/test_map.gd's `layout`,
## selected via GameState.chosen_settlement_id — see scripts/settlement_db.gd), points the
## follow camera at them with the map's bounds for clamping, and binds the HUD's energy bar to
## the player (Phase 2). Phase 3 additionally wires the player to the Farm node (till/plant/
## water/harvest target resolution) and the HUD's hotbar to the player's inventory. Phase 4
## additionally wires Structures (buildings/chest), the chest UI toggle, and grants the chosen
## settlement's starting-resource bonus (ROADMAP.md Phase 4: "differing starting resources").
## Phase 5 Stage 1 wires the NPC roster (scripts/npcs.gd) into player.bind_world() and the
## dialogue box (scripts/dialogue_ui.gd) both ways, the same shape as Builder below: the player
## emits npc_dialogue_requested, DialogueUI owns opening/advancing it, and player.dialogue_ui
## points back so its held-tool polling can stand down while a conversation is open.
## Phase 5 Stage 2 wires Marta's store (scripts/store_ui.gd) one level deeper: DialogueUI emits
## store_requested (when a dialogue choice leads to its OPEN_STORE sentinel), StoreUI owns
## opening/browsing/buying, and player.store_ui points back the same way player.dialogue_ui does.
## Phase 5 Stage 3 wires the shipping box's loading UI (scripts/shipping_ui.gd) and the
## sale-credit hop (structures.crops_sold -> player.add_credits) — see _ready()'s comment.
## The day/night CanvasModulate and DayManager autoload run themselves.

const SettlementDB := preload("res://scripts/settlement_db.gd")
const ModalGate := preload("res://scripts/modal_gate.gd")

@onready var test_map: Node2D = $TestMap
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera
@onready var hud: CanvasLayer = $HUD

## Phase 6: the shared modal mutual-exclusion registry (see modal_gate.gd's class doc). Owned
## here — one per main scene, dying with it — and wired to every modal surface in _ready() below.
## Exposed as a plain field so the test tooling (tools/soak_test.gd) can inspect it.
var modal_gate: ModalGate = ModalGate.new()

## The build/placement-mode node, kept as a field so _process's time-pause poll below can exempt
## it from the "any modal open" check (see that poll's comment for the judgment call).
var _builder: Node2D = null


func _ready() -> void:
	player.global_position = test_map.get_spawn_position()
	camera.set_map_bounds(test_map.get_map_rect())
	camera.set_target(player)
	hud.bind_player(player)
	var structures: Node = test_map.get_node("Structures")
	var npcs: Node = test_map.get_node("Npcs")
	player.bind_world(test_map.get_node("Farm"), test_map, structures, npcs)
	hud.bind_inventory(player.inventory)
	structures.chest_toggled.connect(hud.toggle_chest_ui)
	# Phase 4 Stage 2: build/placement mode (scripts/builder.gd) — bound both ways, since the
	# builder reads the player's facing/inventory and the player suppresses tool swings while
	# placement mode is active.
	var builder: Node2D = $Builder
	builder.bind(player, test_map, structures)
	player.builder = builder
	_builder = builder
	# Phase 5 Stage 1: dialogue box (scripts/dialogue_ui.gd) — bound both ways like Builder above,
	# since player.gd needs to know a conversation is open (to freeze) and DialogueUI needs the
	# signal that says one should start.
	var dialogue_ui: Node = $DialogueUI
	player.npc_dialogue_requested.connect(dialogue_ui.open_dialogue)
	player.dialogue_ui = dialogue_ui
	# Phase 5 Stage 2: Marta's store (scripts/store_ui.gd) — bound both ways like DialogueUI
	# above, one level deeper (dialogue_ui.store_requested rather than a direct player signal),
	# since the store is reached via a dialogue choice, not a direct use_tool interaction.
	var store_ui: Node = $StoreUI
	store_ui.bind(player)
	dialogue_ui.store_requested.connect(store_ui.open_store)
	player.store_ui = store_ui
	# Phase 5 Stage 3: the shipping box's crop-loading UI (scripts/shipping_ui.gd) — bound both
	# ways like StoreUI above, but reached directly from use_tool() facing the box (a world
	# interaction like the chest/bed) rather than through a dialogue choice. The second wire
	# closes the economy loop: structures.gd resolves the box's overnight sale on day_started
	# and emits crops_sold(total), which lands here as player Credits — the "Credits added next
	# morning" checklist line, via the add_credits hook Stage 2 documented for exactly this.
	var shipping_ui: Node = $ShippingUI
	shipping_ui.bind(player, structures)
	player.shipping_box_requested.connect(shipping_ui.open_box)
	player.shipping_ui = shipping_ui
	structures.crops_sold.connect(player.add_credits)
	# Phase 6: register every modal surface with the shared mutual-exclusion gate, so no two of
	# them can ever be open/active at once (the "B mid-conversation" input-conflict fix — see
	# modal_gate.gd's class doc, which also documents the three-line recipe for wiring in future
	# modal UIs like quest journals or pause menus).
	for surface in [builder, dialogue_ui, store_ui, shipping_ui]:
		modal_gate.register(surface)
		surface.modal_gate = modal_gate
	# Phase 4 Stage 3: resuming a save vs. starting fresh. GameState stages loaded save data
	# before this scene instantiates (see settlement_select.gd's resume path); an empty result
	# means new game -> grant the one-time settlement starting bonus instead. Applied here, after
	# every bind above, so restored state flows through the already-connected signals (inventory
	# UI, energy bar) exactly like live changes would.
	var save_data := GameState.take_pending_save()
	if save_data.is_empty():
		_grant_starting_resource_bonus()
	else:
		_apply_save(save_data)


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


## The scene dying (quit-to-boot in the test tooling, a future title-screen return) must never
## leak a frozen clock into the next boot: DayManager is an autoload and outlives this scene,
## and if a modal happened to be open at teardown nothing would ever set time_paused back.
func _exit_tree() -> void:
	DayManager.time_paused = false


## Restores each system's saved state (see scripts/save_data.gd's class doc for the shape) on
## top of the layout-authored world the child nodes' _ready() already built. Order matters only
## in that TestMap's layout was already resolved from the restored chosen_settlement_id in
## _enter_tree(); the per-node load_state() calls are independent overlays. DayManager fields
## are assigned directly — no day_started emission, since re-loading a day must not re-run
## daily ticks (crop growth already happened before the save was written).
func _apply_save(data: Dictionary) -> void:
	DayManager.day = int(data.get("day", 1))
	DayManager.minutes_into_day = float(data.get("minutes_into_day", DayManager.DAY_START_MINUTES))
	test_map.load_state(data.get("map", {}))
	test_map.get_node("Farm").load_state(data.get("farm", {}))
	test_map.get_node("Structures").load_state(data.get("structures", {}))
	player.load_state(data.get("player", {}))


## The chosen settlement's resource-lean bonus (water access / ruin materials / better soil —
## see settlement_db.gd's SETTLEMENTS data), granted once on top of player.gd's fixed starting
## loadout (tools + potato seeds), matching ROADMAP.md Phase 4's "differing starting resources"
## checklist item.
func _grant_starting_resource_bonus() -> void:
	for entry in SettlementDB.starting_items(GameState.chosen_settlement_id):
		player.inventory.add_item(String(entry.get("item_id", "")), int(entry.get("count", 0)))
