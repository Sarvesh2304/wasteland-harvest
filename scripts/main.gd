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
## The day/night CanvasModulate and DayManager autoload run themselves.

const SettlementDB := preload("res://scripts/settlement_db.gd")

@onready var test_map: Node2D = $TestMap
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera
@onready var hud: CanvasLayer = $HUD


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
