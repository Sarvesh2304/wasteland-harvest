extends Node2D
## Root scene glue (ROADMAP Phase 2): spawns the player on the test map, points the follow
## camera at them with the map's bounds for clamping, and binds the HUD's energy bar to the
## player. The day/night CanvasModulate and DayManager autoload run themselves.

@onready var test_map: Node2D = $TestMap
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player.global_position = test_map.get_spawn_position()
	camera.set_map_bounds(test_map.get_map_rect())
	camera.set_target(player)
	hud.bind_player(player)
