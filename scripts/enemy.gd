extends CharacterBody2D
## One enemy in the ruins (Milestone C, 2026-10-07). Stats come from data/enemies.json
## (scripts/enemy_db.gd); scripts/enemies.gd (the zone's director) spawns it and serves the
## world queries: the player, line of sight, A* paths, noise, explosions, projectiles, loot.
##
## States:
##   IDLE: mill about near home; groan now and then.
##   ALERT: a "!" and a beat to react.
##   CHASE: straight at the player while they're in sight, else along an A* path to where they
##   were last seen.
##   WINDUP: the attack telegraph; the enemy holds still in its attack pose.
##   STRIKE, then RECOVER, then back to CHASE.
##   SEARCH: after losing sight for lose_track seconds, a "?" at the last known spot, then home.
## Hits stagger (HURT, which cancels a windup) unless the type is unstaggerable. At 0 HP it
## goes DEAD: death frames, loot, and a corpse that lingers, then fades.
##
## Attack styles (data "attack"):
##   melee: a strike in front.
##   lunge: a dash that bites on contact.
##   explode: swell, then burst for area damage + rads and leave a rad puddle. It also bursts
##   when killed, so kill bloaters at range.
##   ranged: keep distance, aim along a visible line (it tracks, then locks for the last third),
##   fire a projectile.

const EnemyDB := preload("res://scripts/enemy_db.gd")
const Combat := preload("res://scripts/combat.gd")
const FactionScript := preload("res://scripts/faction.gd")

enum State { IDLE, ALERT, CHASE, WINDUP, STRIKE, RECOVER, HURT, SEARCH, DEAD, WARN }

signal died(enemy: Node)

const ALERT_SECONDS := 0.45
const SEARCH_SECONDS := 2.5
const SIGHT_CHECK_SECONDS := 0.15
const REPATH_SECONDS := 0.45
const KNOCK_DECAY := 520.0
const CORPSE_SECONDS := 22.0
const SEPARATION := 9.0
## The body centre relative to the origin (the origin sits at the feet, like the player's).
const BODY_OFFSET := Vector2(0, -5)

var type := "shambler"
var data: Dictionary = {}
var hp := 1
var max_hp := 1
var group := -1
var home := Vector2.ZERO
var state := State.IDLE
var facing := "south"
var director: Node = null
## Raiders while the faction isn't hostile (scripts/faction.gd): they warn instead of attacking,
## until the player crowds them (closer than personal_space) or hits one.
var wary := false
var personal_space := 44.0
## Patrollers walk between home and a far point (global) instead of milling about; set by the
## director at spawn (raider groups together, some runners alone).
var patrol_point := Vector2.ZERO
var _patrol_out := true

var _state_time := 0.0
var _anim_time := 0.0
var _sight_timer := 0.0
var _last_seen := Vector2.ZERO
var _since_seen := 999.0
var _path: PackedVector2Array = PackedVector2Array()
var _path_index := 0
var _repath := 0.0
var _knock := Vector2.ZERO
var _cooldown := 0.0
var _wander_target := Vector2.ZERO
var _wander_wait := 0.0
var _groan_timer := 0.0
var _lunge_dir := Vector2.ZERO
var _aim_dir := Vector2.ZERO
var _struck := false
var _hurt_sound_ready := 0.0
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite2D = null
var _mark: Sprite2D = null
var _aim_line: Line2D = null
var _hp_bar: Node2D = null
var _hp_fill: ColorRect = null
var _hp_bar_timer := 0.0


## Called by the director before add_child; `local_pos` is in the director's space.
func setup(enemy_type: String, local_pos: Vector2, group_id: int, seed_value: int, hp_scale: float = 1.0) -> void:
	type = enemy_type
	data = EnemyDB.get_enemy(enemy_type)
	max_hp = maxi(1, int(round(float(data["hp"]) * hp_scale)))
	hp = max_hp
	group = group_id
	position = local_pos
	_rng.seed = seed_value
	_groan_timer = _rng.randf_range(2.0, 9.0)
	_wander_wait = _rng.randf_range(0.5, 3.0)
	facing = ["south", "north", "east", "west"][_rng.randi_range(0, 3)]


func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 8  # "enemies"
	collision_mask = 1   # world only: enemies slide through each other and the player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(data.get("radius", 5)) - 1.0
	shape.shape = circle
	shape.position = Vector2(0, 1)
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = _sheet_texture()
	_sprite.hframes = EnemyDB.COLUMNS
	_sprite.vframes = EnemyDB.ROWS
	_sprite.position = BODY_OFFSET
	add_child(_sprite)
	_mark = Sprite2D.new()
	_mark.position = Vector2(0, -24)
	_mark.visible = false
	_mark.z_index = 6
	add_child(_mark)
	_build_hp_bar()
	if String(data.get("attack", "")) == "ranged":
		_aim_line = Line2D.new()
		_aim_line.width = 1.0
		_aim_line.default_color = Color(1.0, 0.25, 0.15, 0.55)
		_aim_line.z_index = 5
		_aim_line.visible = false
		add_child(_aim_line)
	_apply_frame()


## -- Queries (director / player / projectiles) --

func is_alive() -> bool:
	return state != State.DEAD


func is_hostile_active() -> bool:
	return state in [State.CHASE, State.WINDUP, State.STRIKE, State.RECOVER, State.HURT, State.ALERT]


func hit_center() -> Vector2:
	return global_position + BODY_OFFSET


func body_radius() -> float:
	return float(data.get("radius", 5))


## -- Being hit --

## A hit from the player (melee or projectile). `from` is where the hit came from.
func take_damage(amount: int, from: Vector2, knockback: float, crit: bool = false) -> void:
	if state == State.DEAD:
		return
	if wary and director != null:
		director.provoke(group, self)
	hp -= amount
	Fx.flash(_sprite, 0.1)
	Fx.float_text(hit_center() + Vector2(0, -10), ("%d!" % amount) if crit else str(amount),
		Color("#ffc948") if crit else Color("#ffedb1"))
	Fx.burst(hit_center(), "rad" if String(data.get("splat", "")) == "ichor" else "blood",
		(global_position - from).normalized(), 0.8 if not crit else 1.3)
	_knock = Combat.knockback_velocity(from, global_position, knockback, float(data.get("weight", 1.0)))
	_show_hp_bar()
	if hp <= 0:
		_die(from)
		return
	if _hurt_sound_ready <= 0.0:
		_hurt_sound_ready = 0.25
		_play_sound("hurt", -4.0)
	_last_seen = from
	_since_seen = 0.0
	var stagger := float(data.get("stagger", 0.3))
	if stagger > 0.0 and state != State.STRIKE:
		_set_state(State.HURT)
		_aim_hide()
	elif state in [State.IDLE, State.SEARCH, State.ALERT]:
		_set_state(State.CHASE)


## Heard something (a gunshot, a scream, a bloater) at `pos`.
func hear(pos: Vector2) -> void:
	if state in [State.IDLE, State.SEARCH]:
		_last_seen = pos
		_since_seen = 0.0
		_set_state(State.ALERT)


## A packmate spotted the player.
func alert_to(pos: Vector2) -> void:
	if state in [State.IDLE, State.SEARCH]:
		_last_seen = pos
		_since_seen = 0.0
		_set_state(State.ALERT)


## -- The loop --

func _physics_process(delta: float) -> void:
	if director != null and director.frozen:
		return
	_state_time += delta
	_anim_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_hurt_sound_ready = maxf(_hurt_sound_ready - delta, 0.0)
	_knock = _knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	if _hp_bar_timer > 0.0:
		_hp_bar_timer -= delta
		if _hp_bar_timer <= 0.0 and _hp_bar != null:
			_hp_bar.visible = false
	var move := Vector2.ZERO
	match state:
		State.IDLE:
			move = _tick_idle(delta)
		State.ALERT:
			if _state_time >= _alert_seconds():
				_set_state(State.CHASE)
		State.CHASE:
			move = _tick_chase(delta)
		State.WINDUP:
			_tick_windup()
		State.STRIKE:
			move = _tick_strike()
		State.RECOVER:
			if _state_time >= float(data["recover"]):
				_cooldown = float(data["cooldown"])
				_set_state(State.CHASE)
		State.HURT:
			if _state_time >= float(data.get("stagger", 0.3)):
				_set_state(State.CHASE)
		State.SEARCH:
			move = _tick_search(delta)
		State.WARN:
			_tick_warn(delta)
		State.DEAD:
			_tick_dead(delta)
			return
	velocity = move + _knock
	if velocity.length_squared() > 0.01:
		move_and_slide()
	if move.length_squared() > 1.0:
		facing = EnemyDB.facing_for(move, facing)
	_apply_frame()


func _tick_idle(delta: float) -> Vector2:
	_groan_timer -= delta
	if _groan_timer <= 0.0:
		_groan_timer = _rng.randf_range(5.0, 11.0)
		_play_sound("idle", -12.0)
	if _look_for_player():
		return Vector2.ZERO
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return Vector2.ZERO
	if patrol_point != Vector2.ZERO:
		# Walk the beat: home -> far point -> home, pausing at each end.
		var goal := patrol_point if _patrol_out else home
		if global_position.distance_to(goal) < 6.0:
			_patrol_out = not _patrol_out
			_wander_wait = _rng.randf_range(2.0, 5.0)
			_path = PackedVector2Array()
			return Vector2.ZERO
		return _follow_path(goal, delta) * float(data["speed"]) + _separation()
	# Mill about within ~2 cells of home.
	if _wander_target == Vector2.ZERO or global_position.distance_to(_wander_target) < 2.0:
		_wander_target = home + Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(-28.0, 28.0))
		_wander_wait = _rng.randf_range(1.0, 4.0)
		return Vector2.ZERO
	var to := _wander_target - global_position
	if get_slide_collision_count() > 0 and _state_time > 0.5:
		_wander_target = Vector2.ZERO
	return to.normalized() * float(data["speed"])


func _look_for_player() -> bool:
	_sight_timer -= get_physics_process_delta_time()
	if _sight_timer > 0.0:
		return false
	_sight_timer = SIGHT_CHECK_SECONDS
	var player := _player()
	if player == null:
		return false
	var d: float = hit_center().distance_to(player.hit_center())
	if d <= float(data["sight"]) and _can_see(player):
		_last_seen = player.global_position
		_since_seen = 0.0
		if wary:
			_set_state(State.WARN)
			return true
		_set_state(State.ALERT)
		if director != null and group >= 0:
			director.alert_group(group, player.global_position, self)
		return true
	return false


func _tick_chase(delta: float) -> Vector2:
	var player := _player()
	if player == null or player.get("dead") == true:
		_set_state(State.SEARCH)
		return Vector2.ZERO
	_since_seen += delta
	_sight_timer -= delta
	var visible_now := false
	if _sight_timer <= 0.0:
		_sight_timer = SIGHT_CHECK_SECONDS
		if hit_center().distance_to(player.hit_center()) <= float(data["sight"]) * 1.6 and _can_see(player):
			_last_seen = player.global_position
			_since_seen = 0.0
	visible_now = _since_seen < SIGHT_CHECK_SECONDS * 2.0
	if _since_seen > float(data["lose_track"]):
		_set_state(State.SEARCH)
		return Vector2.ZERO
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var attack := String(data["attack"])
	if visible_now and _cooldown <= 0.0:
		var start := false
		match attack:
			"melee", "explode":
				start = dist <= float(data["attack_range"])
			"lunge":
				start = dist <= float(data["attack_range"]) and dist > 10.0
			"ranged":
				start = dist <= float(data["attack_range"])
		if start:
			facing = EnemyDB.facing_for(to_player, facing)
			_aim_dir = to_player.normalized()
			_set_state(State.WINDUP)
			return Vector2.ZERO
	var speed := float(data["chase_speed"])
	var move := Vector2.ZERO
	if attack == "ranged" and visible_now:
		# Keep a comfortable distance: back off when crowded, close in when far.
		var keep := float(data.get("keep_away", 52))
		if dist < keep:
			move = -to_player.normalized() * speed * 0.8
		elif dist > float(data["attack_range"]) * 0.85:
			move = to_player.normalized() * speed
		else:
			move = to_player.normalized().orthogonal() * speed * 0.35 * (1.0 if group % 2 == 0 else -1.0)
	elif visible_now:
		move = to_player.normalized() * speed
	else:
		move = _follow_path(_last_seen, delta) * speed
	return move + _separation()


func _tick_windup() -> void:
	var player := _player()
	var windup := float(data["windup"])
	var attack := String(data["attack"])
	if player != null:
		var to_player: Vector2 = player.global_position - global_position
		# Track the player for the first two thirds; the last third is locked (the dodge window).
		if _state_time < windup * 0.66 or attack != "ranged":
			_aim_dir = to_player.normalized() if to_player.length() > 0.1 else _aim_dir
			if attack != "lunge" or _state_time < windup * 0.66:
				facing = EnemyDB.facing_for(to_player, facing)
	if attack == "ranged" and _aim_line != null:
		_aim_line.visible = true
		_aim_line.points = PackedVector2Array([BODY_OFFSET, BODY_OFFSET + _aim_dir * 90.0])
		_aim_line.default_color = Color(1.0, 0.25, 0.15, 0.35 + 0.5 * clampf(_state_time / windup, 0.0, 1.0))
	if attack == "explode":
		var pulse := 1.0 + 0.12 * sin(_state_time * 30.0) * clampf(_state_time / windup, 0.0, 1.0)
		_sprite.scale = Vector2(pulse, pulse)
		_sprite.modulate = Color(1.0 + _state_time, 1.0 + _state_time * 0.6, 1.0, 1.0)
	if _state_time >= windup:
		_struck = false
		_lunge_dir = _aim_dir
		_set_state(State.STRIKE)
		_start_strike()


func _start_strike() -> void:
	var attack := String(data["attack"])
	_play_sound("attack", -3.0)
	match attack:
		"melee":
			_melee_hit(float(data["attack_range"]) + 6.0)
		"explode":
			_explode()
		"ranged":
			_aim_hide()
			if director != null:
				director.fire_enemy_shot(hit_center(), _aim_dir, self)


func _tick_strike() -> Vector2:
	var attack := String(data["attack"])
	var move := Vector2.ZERO
	if attack == "lunge":
		move = _lunge_dir * float(data.get("lunge_speed", 140))
		if not _struck:
			_melee_hit(body_radius() + 7.0)
	if _state_time >= float(data["strike"]):
		_set_state(State.RECOVER)
	return move


func _melee_hit(reach: float) -> void:
	var player := _player()
	if player == null or _struck:
		return
	if Combat.in_melee_arc(hit_center(), _aim_dir, reach, player.hit_center(), 5.0, 130.0):
		_struck = true
		player.take_hit(int(data["damage"]), global_position, 110.0, float(data.get("rads", 0)))


func _explode() -> void:
	if director != null:
		director.explosion(global_position, float(data.get("explode_radius", 28)), int(data["damage"]),
			float(data.get("rads", 0)), self)
	_die(global_position, true)


## A wary raider: gun half-raised, eyes on the player. Too close and the whole group turns.
func _tick_warn(delta: float) -> void:
	var player := _player()
	if player == null:
		_set_state(State.IDLE)
		return
	var to_player: Vector2 = player.global_position - global_position
	facing = EnemyDB.facing_for(to_player, facing)
	_since_seen += delta
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = SIGHT_CHECK_SECONDS
		if hit_center().distance_to(player.hit_center()) <= float(data["sight"]) and _can_see(player):
			_since_seen = 0.0
	if to_player.length() < personal_space and director != null:
		director.provoke(group, self)
		return
	if _since_seen > 4.0:
		_mark.visible = false
		_set_state(State.IDLE)


## The group's patience ran out (crowded, or one of them was hit): fight.
func turn_hostile(pos: Vector2) -> void:
	wary = false
	if state == State.DEAD:
		return
	_last_seen = pos
	_since_seen = 0.0
	if state in [State.IDLE, State.SEARCH, State.WARN]:
		_set_state(State.ALERT)


func _tick_search(delta: float) -> Vector2:
	_mark_show("question")
	if _look_for_player():
		return Vector2.ZERO
	if _state_time < SEARCH_SECONDS:
		if global_position.distance_to(_last_seen) > 6.0:
			return _follow_path(_last_seen, delta) * float(data["speed"]) * 1.2
		return Vector2.ZERO
	# Give up: wander home.
	if global_position.distance_to(home) > 8.0:
		return _follow_path(home, delta) * float(data["speed"])
	_mark.visible = false
	_set_state(State.IDLE)
	return Vector2.ZERO


func _tick_dead(delta: float) -> void:
	var step := mini(int(_state_time / 0.12), 3)
	_sprite.frame = EnemyDB.frame_index("death", facing, step)
	_sprite.scale = Vector2.ONE
	if _state_time > CORPSE_SECONDS:
		_sprite.modulate.a = maxf(0.0, 1.0 - (_state_time - CORPSE_SECONDS) / 2.0)
		if _sprite.modulate.a <= 0.0:
			queue_free()


## -- Helpers --

func _set_state(s: State) -> void:
	if state == State.DEAD:
		return
	var was := state
	state = s
	_state_time = 0.0
	if s != State.WINDUP:
		_sprite.scale = Vector2.ONE
		_sprite.modulate = Color.WHITE
	match s:
		State.ALERT:
			if was in [State.IDLE, State.SEARCH, State.WARN]:
				_mark_show("alert")
				_play_sound("alert", -2.0)
		State.WARN:
			if was != State.WARN:
				_mark_show("alert")
				_mark.modulate = Color(1.0, 0.85, 0.3)
				_play_sound("alert", -6.0)
				var lines: Array[String] = FactionScript.WARNINGS
				Fx.float_text(hit_center() + Vector2(0, -22), lines[_rng.randi_range(0, lines.size() - 1)],
					Color("#ffb72d"), 10.0, 2.2)
		State.CHASE:
			_mark.visible = false
			_path = PackedVector2Array()
			_repath = 0.0
		State.SEARCH:
			_path = PackedVector2Array()
			_aim_hide()
		State.IDLE:
			_wander_target = Vector2.ZERO
	if s != State.WINDUP:
		_aim_hide()


func _alert_seconds() -> float:
	return ALERT_SECONDS * (0.6 if float(data["chase_speed"]) > 45.0 else 1.0)


func _player() -> Node:
	return director.player if director != null else null


func _can_see(player: Node) -> bool:
	return director == null or director.has_los(hit_center(), player.hit_center())


## Unit direction along an A* path toward `target`, repathing every REPATH_SECONDS.
func _follow_path(target: Vector2, delta: float) -> Vector2:
	_repath -= delta
	if director == null:
		return (target - global_position).normalized()
	if _repath <= 0.0 or _path.is_empty():
		_repath = REPATH_SECONDS
		_path = director.path_between(global_position, target)
		_path_index = 0
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 4.0:
		_path_index += 1
	if _path_index >= _path.size():
		var direct := target - global_position
		return direct.normalized() if direct.length() > 3.0 else Vector2.ZERO
	return (_path[_path_index] - global_position).normalized()


## A gentle push away from packmates so a horde fans out instead of stacking.
func _separation() -> Vector2:
	if director == null:
		return Vector2.ZERO
	var push := Vector2.ZERO
	for other in director.live_enemies():
		if other == self:
			continue
		var d: Vector2 = global_position - (other as Node2D).global_position
		var dist := d.length()
		if dist > 0.01 and dist < SEPARATION:
			push += d / dist * (SEPARATION - dist) * 3.0
	return push


func _die(from: Vector2, burst_already: bool = false) -> void:
	if state == State.DEAD:
		return
	var was_exploder := String(data["attack"]) == "explode"
	state = State.DEAD
	_state_time = 0.0
	_mark.visible = false
	_aim_hide()
	if _hp_bar != null:
		_hp_bar.visible = false
	collision_layer = 0
	_sprite.scale = Vector2.ONE
	_sprite.modulate = Color.WHITE
	z_index = -1
	_play_sound("die", -1.0)
	if was_exploder and not burst_already and director != null:
		director.explosion(global_position, float(data.get("explode_radius", 28)) * 0.85,
			int(round(float(data["damage"]) * 0.7)), float(data.get("rads", 0)) * 0.7, self)
	if director != null:
		director.on_enemy_died(self, from)
	died.emit(self)


func _apply_frame() -> void:
	if _sprite == null or state == State.DEAD:
		return
	match state:
		State.WINDUP:
			var telegraph := _state_time >= float(data["windup"]) * 0.4
			_sprite.frame = EnemyDB.frame_index("attack", facing, 1 if telegraph else 0)
		State.STRIKE:
			_sprite.frame = EnemyDB.frame_index("attack", facing, 2)
		State.RECOVER:
			_sprite.frame = EnemyDB.frame_index("attack", facing, 3)
		State.HURT:
			_sprite.frame = EnemyDB.frame_index("hurt", facing, 0)
		State.WARN:
			_sprite.frame = EnemyDB.frame_index("attack", facing, 0)
		_:
			if velocity.length_squared() > 4.0:
				var fps := 4.0 + velocity.length() / 8.0
				_sprite.frame = EnemyDB.frame_index("walk", facing, int(_anim_time * fps))
			else:
				_sprite.frame = EnemyDB.frame_index("idle", facing, int(_anim_time * 2.5))


func _mark_show(kind: String) -> void:
	var path := "res://art/fx/alert_mark.png" if kind == "alert" else "res://art/fx/question_mark.png"
	if ResourceLoader.exists(path):
		_mark.texture = load(path)
	else:
		_mark.texture = null
	_mark.visible = _mark.texture != null
	_mark.modulate = Color.WHITE
	if kind == "alert" and _mark.visible:
		_mark.scale = Vector2(0.4, 1.6)
		var tw := _mark.create_tween()
		tw.tween_property(_mark, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _aim_hide() -> void:
	if _aim_line != null:
		_aim_line.visible = false


func _build_hp_bar() -> void:
	_hp_bar = Node2D.new()
	_hp_bar.position = Vector2(-7, -22)
	_hp_bar.z_index = 5
	_hp_bar.visible = false
	var bg := ColorRect.new()
	bg.size = Vector2(14, 3)
	bg.color = Color("#281a0b")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.add_child(bg)
	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(1, 1)
	_hp_fill.size = Vector2(12, 1)
	_hp_fill.color = Color("#c43020")
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.add_child(_hp_fill)
	add_child(_hp_bar)


func _show_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.visible = true
	_hp_bar_timer = 3.0
	_hp_fill.size.x = 12.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0)


func _play_sound(event: String, volume_db: float) -> void:
	var s := EnemyDB.sound(type, event)
	if s != "" and Audio.has_sfx(s):
		Audio.play_sfx_at(s, global_position, volume_db)


## The enemy's sheet, or a generated stand-in (until its art exists).
func _sheet_texture() -> Texture2D:
	var path := EnemyDB.sheet_path(type)
	if ResourceLoader.exists(path):
		return load(path)
	return _placeholder_sheet(type)


static var _placeholders: Dictionary = {}


static func _placeholder_sheet(enemy_type: String) -> Texture2D:
	if _placeholders.has(enemy_type):
		return _placeholders[enemy_type]
	var colors := {"shambler": Color("#5f6e55"), "runner": Color("#9aa585"), "bloater": Color("#bca843"),
		"rad_hound": Color("#7d452a"), "raider": Color("#a65c30")}
	var body: Color = colors.get(enemy_type, Color("#888888"))
	var f := EnemyDB.FRAME
	var img := Image.create(f * EnemyDB.COLUMNS, f * EnemyDB.ROWS, false, Image.FORMAT_RGBA8)
	for row in EnemyDB.ROWS:
		for col in EnemyDB.COLUMNS:
			var ox := col * f
			var oy := row * f
			var dead := row == EnemyDB.ROW_DEATH and col == 3
			for y in f:
				for x in f:
					var dx := (x - f / 2.0) / (8.0 if dead else 5.0)
					var dy := (y - (f - 6.0 if dead else f / 2.0 + 2.0)) / (3.0 if dead else 8.0)
					if dx * dx + dy * dy <= 1.0:
						img.set_pixel(ox + x, oy + y, body.darkened(0.3) if dx * dx + dy * dy > 0.7 else body)
	var tex := ImageTexture.create_from_image(img)
	_placeholders[enemy_type] = tex
	return tex
