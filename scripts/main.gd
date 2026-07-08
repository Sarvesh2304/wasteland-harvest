extends Node2D
## Root scene glue: spawns the player on the active map (scripts/test_map.gd's `layout`,
## selected via GameState.chosen_settlement_id — see scripts/settlement_db.gd), points the
## follow camera at them with the map's bounds for clamping, and binds the HUD's energy bar to
## the player (Phase 2). Phase 3 additionally wires the player to the Farm node (till/plant/
## water/harvest target resolution) and the HUD's hotbar to the player's inventory. Phase 4
## additionally wires Structures (buildings/chest), the chest UI toggle, and grants the chosen
## settlement's starting-resource bonus (ROADMAP.md Phase 4: "differing starting resources").
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
	player.bind_world(test_map.get_node("Farm"), test_map, structures)
	hud.bind_inventory(player.inventory)
	structures.chest_toggled.connect(hud.toggle_chest_ui)
	_grant_starting_resource_bonus()


## The chosen settlement's resource-lean bonus (water access / ruin materials / better soil —
## see settlement_db.gd's SETTLEMENTS data), granted once on top of player.gd's fixed starting
## loadout (tools + potato seeds), matching ROADMAP.md Phase 4's "differing starting resources"
## checklist item.
func _grant_starting_resource_bonus() -> void:
	for entry in SettlementDB.starting_items(GameState.chosen_settlement_id):
		player.inventory.add_item(String(entry.get("item_id", "")), int(entry.get("count", 0)))
