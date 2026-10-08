extends SceneTree
## Milestone C combat smoke (2026-10-08): each enemy type's signature behaviour, one at a time,
## in a cleared ruins level, through the real AI and the real player:
##   1. A wary raider warns (no shots) while the player keeps their distance; crowding it turns
##      it hostile and it shoots.
##   2. A bloater swells and bursts: damage + rads, and a rad puddle left behind.
##   3. A rad-hound lunges and bites: damage + rads.
##   4. The pipe pistol spends a round, hurts a shambler, and the gunshot pulls a far-off enemy
##      in; with no ammo it just clicks.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/combat_smoke.gd

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var director: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _enemy: Node = null
var _far: Node = null
var _hp := 0.0
var _rads := 0.0


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.save_path = "user://combat_smoke_save.json"
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	stage = to_stage
	ticks = 0


func _physics_process(_delta: float) -> bool:
	ticks += 1
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			day_manager.minutes_into_day = 9 * 60.0
			main.expedition.depart()
			director = main.ruins["enemies"]
			_next(1)
		1:
			if ticks < 5:
				return false
			_clear_enemies()
			_enemy = _spawn("raider", Vector2(70, 0))
			_hp = player.hp
			_next(2)
		2:
			if ticks < 120:
				return false
			_check(_enemy.state == _enemy.State.WARN, "the raider warns instead of attacking (state %d)" % _enemy.state)
			_check(is_equal_approx(player.hp, _hp), "no shots while the player keeps their distance")
			# Crowd it.
			player.global_position = _enemy.global_position + Vector2(-26, 0)
			_next(3)
		3:
			if ticks < 300 and is_equal_approx(player.hp, _hp):
				return false
			_check(not _enemy.wary, "crowded, the raider turned hostile")
			_check(player.hp < _hp, "and shot the player (hp %.0f -> %.0f)" % [_hp, player.hp])
			_check(main.expedition.raider_rep < 0, "provoking raiders cost reputation (%d)" % main.expedition.raider_rep)
			# -- Bloater --
			_clear_enemies()
			player.revive(player.effective_max_hp())
			player._iframes = 0.0
			_enemy = _spawn("bloater", Vector2(14, 0))
			_hp = player.hp
			_rads = player.rads
			_next(4)
		4:
			if ticks < 240 and _enemy != null and is_instance_valid(_enemy) and _enemy.is_alive():
				return false
			_check(_enemy == null or not is_instance_valid(_enemy) or not _enemy.is_alive(), "the bloater burst")
			_check(player.hp < _hp, "the burst hurt (hp %.0f -> %.0f)" % [_hp, player.hp])
			_check(player.rads > _rads, "and irradiated (%.1f rads)" % player.rads)
			_check(director.rad_rate_at(player.global_position) > 0.0 or director._rad_sources.size() > 0,
				"a rad puddle was left behind")
			# -- Rad-hound --
			_clear_enemies()
			director._rad_sources.clear()
			player.revive(player.effective_max_hp())
			player._iframes = 0.0
			_enemy = _spawn("rad_hound", Vector2(60, 0))
			_hp = player.hp
			_rads = player.rads
			_next(5)
		5:
			if ticks < 300 and is_equal_approx(player.hp, _hp):
				return false
			_check(player.hp < _hp, "the hound's bite hurt (hp %.0f -> %.0f)" % [_hp, player.hp])
			_check(player.rads > _rads, "and the bite carried rads")
			# -- Pipe pistol --
			_clear_enemies()
			player.revive(player.effective_max_hp())
			player._iframes = 99.0
			_enemy = _spawn("shambler", Vector2(48, 0))
			_far = _spawn("shambler", Vector2(170, 40))
			player.inventory.add_item("pipe_pistol", 1)
			player.inventory.add_item("pistol_ammo", 3)
			_select("pipe_pistol")
			player.facing = "east"
			player._mouse_aim_until = 0.0
			player._attack_cd = 0.0
			player.use_tool()
			_check(player.inventory.count_of("pistol_ammo") == 2, "one round spent")
			_next(6)
		6:
			if ticks < 40:
				return false
			_check(_enemy.hp < _enemy.max_hp, "the shot hit (hp %d/%d)" % [_enemy.hp, _enemy.max_hp])
			_check(_far.state != _far.State.IDLE, "the gunshot pulled the far shambler in (state %d)" % _far.state)
			player.inventory.remove_item("pistol_ammo", 99)
			player._attack_cd = 0.0
			player.using_tool = false
			player.use_tool()
			_check(player.inventory.count_of("pistol_ammo") == 0, "no ammo, nothing fired")
			_finish()
			return true
	return false


func _clear_enemies() -> void:
	for e in director.live_enemies():
		e.queue_free()


## Spawns one enemy `offset` px from the player, in the open.
func _spawn(type: String, offset: Vector2) -> Node:
	var map: Node2D = main.ruins["map"]
	# Stand the player in the open middle of the fallback level's street.
	player.global_position = map.get_global_cell_center(Vector2i(10, 9))
	player.velocity = Vector2.ZERO
	var local := map.to_local(player.global_position + offset)
	var enemy: CharacterBody2D = load("res://scripts/enemy.gd").new()
	enemy.director = director
	enemy.setup(type, local, 7, 99, 1.0)
	if type == "raider":
		enemy.wary = true
		enemy.personal_space = 44.0
	director.add_child(enemy)
	return enemy


func _select(item_id: String) -> void:
	for i in player.inventory.TOTAL_SLOTS:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item_id:
			if i >= player.inventory.HOTBAR_SIZE:
				player.inventory.move_slot(i, player.inventory.HOTBAR_SIZE - 1)
				i = player.inventory.HOTBAR_SIZE - 1
			player.inventory.select_hotbar(i)
			return


func _finish() -> void:
	game_state.delete_save()
	if failures.is_empty():
		print("COMBAT SMOKE: all checks passed (wary raider -> provoked, bloater burst, hound bite, pistol + noise + empty click).")
		quit(0)
	else:
		for f in failures:
			print("COMBAT SMOKE FAIL: " + f)
		quit(1)
