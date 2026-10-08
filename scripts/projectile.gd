extends Node2D
## A flying shot (Milestone C, 2026-10-07): the player's bolts, stones, bullets and pellets, and
## raiders' bullets. It steps along its velocity each physics frame, testing the swept segment
## against the "world" layer (walls, buildings, wrecks stop it) and then against its targets:
## enemies for the player's shots, the player for enemy shots. Spawned and served by
## scripts/enemies.gd. Crossbow bolts can survive the flight and be picked back up.

const Combat := preload("res://scripts/combat.gd")

var velocity := Vector2.ZERO
var damage := 0
var knockback := 0.0
var crit := false
var from_player := true
var max_distance := Combat.PROJECTILE_RANGE
## An item left behind where the shot stops (crossbow bolts), with this chance.
var drop_item := ""
var drop_chance := 0.0
var director: Node = null

var _travelled := 0.0
var _done := false


## `texture_path` is the shot's art (pointing east); a small tracer stands in without it.
func setup(origin: Vector2, dir: Vector2, speed: float, shot_damage: int, shot_knockback: float,
		player_shot: bool, texture_path: String = "") -> void:
	global_position = origin
	velocity = dir.normalized() * speed
	damage = shot_damage
	knockback = shot_knockback
	from_player = player_shot
	rotation = velocity.angle()
	z_index = 6
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path)
		add_child(sprite)
	else:
		var tracer := ColorRect.new()
		tracer.size = Vector2(5, 1)
		tracer.position = Vector2(-4, 0)
		tracer.color = Color("#ffe066") if player_shot else Color("#ff8a3d")
		tracer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tracer)


func _physics_process(delta: float) -> void:
	if _done or (director != null and director.frozen):
		return
	var a := global_position
	var b := a + velocity * delta
	var wall = director.raycast_world(a, b) if director != null else null
	var end: Vector2 = wall if wall != null else b
	if director != null:
		if from_player:
			var enemy: Node = director.first_enemy_on_segment(a, end, 2.0)
			if enemy != null:
				enemy.take_damage(damage, a - velocity.normalized() * 10.0, knockback, crit)
				_finish(enemy.hit_center(), false)
				return
		else:
			var player: Node = director.player
			if player != null and not bool(player.get("dead")) \
					and Combat.segment_hits_circle(a, end, player.hit_center(), 5.0):
				player.take_hit(damage, a, knockback, 0.0)
				_finish(player.hit_center(), false)
				return
	global_position = end
	_travelled += a.distance_to(end)
	if wall != null:
		_finish(end, true)
	elif _travelled >= max_distance:
		_finish(end, false)


func _finish(at: Vector2, hit_wall: bool) -> void:
	_done = true
	if hit_wall:
		Fx.burst(at, "stone", -velocity.normalized(), 0.35)
		Audio.play_sfx_at("bullet_impact", at, -10.0)
	if drop_item != "" and director != null and randf() < drop_chance:
		director.drop_item(drop_item, 1, at - velocity.normalized() * 4.0)
	queue_free()
