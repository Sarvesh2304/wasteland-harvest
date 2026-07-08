extends Node2D
## Root scene glue: spawns the player on the test map, points the follow camera at them with
## the map's bounds for clamping, and binds the HUD's energy bar to the player (Phase 2). Phase
## 3 additionally wires the player to the Farm node (till/plant/water/harvest target
## resolution) and the HUD's hotbar to the player's inventory. The day/night CanvasModulate and
## DayManager autoload run themselves.

@onready var test_map: Node2D = $TestMap
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.global_position = test_map.get_spawn_position()
	camera.set_map_bounds(test_map.get_map_rect())
	camera.set_target(player)
	hud.bind_player(player)
	player.bind_world(test_map.get_node("Farm"), test_map)
	hud.bind_inventory(player.inventory)
