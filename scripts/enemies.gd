extends Node2D
## The ruins zone's enemy director (Milestone C, 2026-10-07). It spawns the level's enemies
## (scripts/enemy.gd) and serves them the world:
##   - the player;
##   - line of sight: raycasts against the "world" layer (walls, buildings, wrecks);
##   - paths: AStarGrid2D over the zone's cells, kept in sync as breakables are smashed;
##   - noise (a gunshot pulls in everything within earshot) and pack alerts;
##   - melee sweeps and projectiles, for the player and for raiders;
##   - explosions, which hurt everyone, so a bloater can be used;
##   - rad sources and the puddles bloaters leave;
##   - loot, XP and blood on kills.
##
## A child of the ruins map, y-sorted, so enemies and corpses sort with the player like every
## other world object. It also tells main.gd when a fight starts and ends (combat_changed), so
## the music can follow.

const Enemy := preload("res://scripts/enemy.gd")
const EnemyDB := preload("res://scripts/enemy_db.gd")
const Combat := preload("res://scripts/combat.gd")
const Radiation := preload("res://scripts/radiation.gd")
const Projectile := preload("res://scripts/projectile.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const FactionScript := preload("res://scripts/faction.gd")
const LootDB := preload("res://scripts/loot_db.gd")

const CELL := 16
## Combat music lingers this long after the last enemy stops hunting the player.
const COMBAT_LINGER := 6.0
## Enemy toughness per depth beyond the first.
const HP_PER_DEPTH := 0.15
const SPLAT_SECONDS := 60.0
const RAD_PUDDLE_SHEET := "res://art/env/ruins/rad_puddle.png"

signal combat_changed(active: bool)
signal enemy_killed(enemy_type: String)
## The player started trouble with a wary raider group (scripts/faction.gd).
signal raider_provoked

var player: Node = null
var depth := 1
var kills := 0
## The raider faction's view of the player (set by the expedition before spawning).
var raider_rep := 0
## True while the player has a menu, prompt or note open: enemies and shots hold still, like the
## clock does (Stardew pauses the world behind its menus).
var frozen := false

var _map: Node2D = null
var _objects: Node = null
var _astar := AStarGrid2D.new()
var _nav_ready := false
var _rng := RandomNumberGenerator.new()
## {pos: Vector2 (global), strength: float, radius: float, until: float (-1 = forever), node}
var _rad_sources: Array = []
var _combat_active := false
var _combat_linger := 0.0
var _time := 0.0
var _splats: Array = []


func _ready() -> void:
	y_sort_enabled = true


## Binds the director to its zone: the map (layout + cells) and its world objects.
func setup(map: Node2D, objects: Node, player_node: Node) -> void:
	_map = map
	_objects = objects
	player = player_node


## -- Spawning --

## Spawns `entries` ([{type, cell: Vector2i, group}]) for a level at `level_depth`.
func spawn_enemies(entries: Array, level_depth: int, seed_value: int) -> void:
	depth = maxi(level_depth, 1)
	_rng.seed = seed_value
	var hp_scale := 1.0 + HP_PER_DEPTH * float(depth - 1)
	var group_beats := {}  # group -> [first member's cell, far cell]
	for i in entries.size():
		var e: Dictionary = entries[i]
		var type := String(e.get("type", "shambler"))
		if not EnemyDB.has_enemy(type):
			continue
		var cell: Vector2i = e.get("cell", Vector2i.ZERO)
		var enemy: CharacterBody2D = Enemy.new()
		enemy.director = self
		enemy.setup(type, _cell_feet(cell), int(e.get("group", -1)), seed_value * 31 + i, hp_scale)
		if type == "raider" and not FactionScript.attacks_on_sight(raider_rep):
			enemy.wary = true
			enemy.personal_space = FactionScript.personal_space(raider_rep)
		add_child(enemy)
		# Raider groups walk a beat together; about a third of runners roam alone.
		var group_id := int(e.get("group", -1))
		var patrols := type == "raider" or (type == "runner" and _rng.randf() < 0.35)
		if patrols and _nav_ready:
			var far := Vector2i(-1, -1)
			var offset := Vector2i.ZERO
			if group_id >= 0 and group_beats.has(group_id):
				far = group_beats[group_id][1]
				offset = cell - Vector2i(group_beats[group_id][0])
			else:
				far = _far_open_cell(cell, 6, 12)
				if group_id >= 0:
					group_beats[group_id] = [cell, far]
			var target := _nearest_open(far + offset)
			if far != Vector2i(-1, -1) and target != Vector2i(-1, -1):
				enemy.patrol_point = _map.to_global(_cell_feet(target))


## Removes every enemy, shot, splat and rad source (a new level, or going home).
func clear() -> void:
	for child in get_children():
		child.queue_free()
	_rad_sources.clear()
	_splats.clear()
	kills = 0
	_set_combat(false)


func live_enemies() -> Array:
	var out: Array = []
	for child in get_children():
		if child is Enemy and (child as Enemy).is_alive() and not child.is_queued_for_deletion():
			out.append(child)
	return out


func live_count() -> int:
	return live_enemies().size()


## -- World queries --

## (Re)builds the A* grid from the zone's solid cells (layout terrain + solid objects).
func rebuild_nav() -> void:
	if _map == null or _map.layout == null:
		return
	var size: Vector2i = _map.layout.size()
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.offset = Vector2(CELL / 2.0, CELL / 2.0)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if _cell_solid(c):
				_astar.set_point_solid(c, true)
	_nav_ready = true


func set_cell_solid(cell: Vector2i, solid: bool) -> void:
	if _nav_ready and _astar.is_in_boundsv(cell):
		_astar.set_point_solid(cell, solid)


func _cell_solid(c: Vector2i) -> bool:
	if _map.layout.is_solid(c.x, c.y):
		return true
	if _objects != null and _objects.is_solid_at(c):
		return true
	return _map.has_method("is_blocked_at") and _map.is_blocked_at(c)


## A walkable path (global points) from `from` toward `to`; partial if `to` can't be reached.
func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _nav_ready or _map == null:
		return out
	var a := _nearest_open(_map.world_to_cell(from))
	var b := _nearest_open(_map.world_to_cell(to))
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return out
	for p in _astar.get_point_path(a, b, true):
		out.append(_map.to_global(p))
	return out


## A random open cell `min_r`..`max_r` cells from `from` that a path actually reaches, or
## (-1, -1). Used for patrol beats.
func _far_open_cell(from: Vector2i, min_r: int, max_r: int) -> Vector2i:
	for attempt in 24:
		var angle := _rng.randf() * TAU
		var r := _rng.randf_range(float(min_r), float(max_r))
		var c := from + Vector2i(roundi(cos(angle) * r), roundi(sin(angle) * r))
		if not _astar.is_in_boundsv(c) or _astar.is_point_solid(c):
			continue
		var path := _astar.get_id_path(from, c)
		if not path.is_empty() and path.size() <= max_r * 2:
			return c
	return Vector2i(-1, -1)


func _nearest_open(cell: Vector2i) -> Vector2i:
	if _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell):
		return cell
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
					return c
	return Vector2i(-1, -1)


## True when nothing on the "world" layer stands between `a` and `b`.
func has_los(a: Vector2, b: Vector2) -> bool:
	return raycast_world(a, b) == null


## Where the segment a->b first hits the "world" layer, or null.
func raycast_world(a: Vector2, b: Vector2) -> Variant:
	if not is_inside_tree() or a.distance_squared_to(b) < 0.01:
		return null
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(a, b, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"]


## -- Alerts and noise --

## A wary raider was crowded or hit: its whole group turns on the player.
func provoke(group: int, source: Node) -> void:
	var pos: Vector2 = player.global_position if player != null else (source as Node2D).global_position
	var any_was_wary := false
	for e in live_enemies():
		var enemy: Enemy = e
		if enemy.type != "raider":
			continue
		if enemy == source or (group >= 0 and enemy.group == group):
			any_was_wary = any_was_wary or enemy.wary
			enemy.turn_hostile(pos)
	if any_was_wary:
		raider_provoked.emit()

func alert_group(group: int, pos: Vector2, source: Node = null) -> void:
	if group < 0:
		return
	for e in live_enemies():
		if e != source and (e as Enemy).group == group:
			(e as Enemy).alert_to(pos)


## Everything within `radius` of `pos` comes to look.
func noise(pos: Vector2, radius: float) -> void:
	for e in live_enemies():
		if (e as Node2D).global_position.distance_to(pos) <= radius:
			(e as Enemy).hear(pos)


## -- The player's attacks --

## A melee sweep. Returns how many enemies it hit.
func melee_attack(origin: Vector2, aim: Vector2, reach: float, base_damage: int, knockback: float,
		multiplier: float) -> int:
	var hits := 0
	for e in live_enemies():
		var enemy: Enemy = e
		if Combat.in_melee_arc(origin, aim, reach, enemy.hit_center(), enemy.body_radius()):
			var roll := Combat.roll_damage(base_damage, _rng, multiplier)
			enemy.take_damage(int(roll["damage"]), origin, knockback * (1.3 if roll["crit"] else 1.0),
				bool(roll["crit"]))
			hits += 1
	return hits


## The first live enemy whose body the segment a->b passes through (nearest to a).
func first_enemy_on_segment(a: Vector2, b: Vector2, pad: float) -> Node:
	var best: Node = null
	var best_d := INF
	for e in live_enemies():
		var enemy: Enemy = e
		if Combat.segment_hits_circle(a, b, enemy.hit_center(), enemy.body_radius() + pad):
			var d := a.distance_to(enemy.hit_center())
			if d < best_d:
				best_d = d
				best = enemy
	return best


## The player fires `weapon_id` from `origin` along `aim` (ammo already spent by the caller).
func fire_player_shot(origin: Vector2, aim: Vector2, weapon_id: String, multiplier: float) -> void:
	var item := ItemDB.get_item(weapon_id)
	var ammo := String(item.get("ammo_item", ""))
	var texture := "res://art/fx/shot.png"
	if ammo == "crossbow_bolt":
		texture = "res://art/fx/bolt.png"
	elif ammo == "stone":
		texture = "res://art/fx/stone_shot.png"
	var dirs := Combat.pellet_directions(aim, int(item.get("pellets", 1)), float(item.get("spread_degrees", 0.0)))
	for dir in dirs:
		var shot: Node2D = Projectile.new()
		shot.director = self
		var roll := Combat.roll_damage(int(item.get("damage", 5)), _rng, multiplier)
		add_child(shot)
		shot.setup(origin + dir * 6.0, dir, float(item.get("projectile_speed", 300)), int(roll["damage"]),
			float(item.get("knockback", 60)), true, texture)
		shot.crit = bool(roll["crit"])
		if ammo == "crossbow_bolt":
			shot.drop_item = ammo
			shot.drop_chance = Combat.BOLT_RECOVERY_CHANCE
	noise(origin, Combat.noise_radius(weapon_id))


## A raider's shot.
func fire_enemy_shot(origin: Vector2, aim: Vector2, enemy: Node) -> void:
	var data: Dictionary = (enemy as Enemy).data
	var shot: Node2D = Projectile.new()
	shot.director = self
	add_child(shot)
	shot.setup(origin + aim * 6.0, aim, float(data.get("projectile_speed", 200)), int(data["damage"]), 70.0,
		false, "res://art/fx/shot.png")
	Fx.burst(origin + aim * 7.0, "sparkle", aim, 0.4)


## -- Explosions, radiation --

## A burst: damage (falling off to half at the edge) to the player and every other enemy in
## `radius`, plus rads, an ichor splash and a rad puddle left behind.
func explosion(pos: Vector2, radius: float, damage: int, rads: float, source: Node = null) -> void:
	Fx.burst(pos + Vector2(0, -4), "rad", Vector2.UP, 2.5)
	Fx.burst(pos + Vector2(0, -4), "smoke", Vector2.UP, 1.5)
	Fx.shake(2.5, 0.25)
	Audio.play_sfx_at("explosion", pos, -2.0)
	_add_splat(pos, "ichor")
	if player != null and not bool(player.get("dead")):
		var d: float = player.hit_center().distance_to(pos)
		if d <= radius:
			var falloff := 1.0 - 0.5 * clampf(d / radius, 0.0, 1.0)
			player.take_hit(int(round(damage * falloff)), pos, 160.0, rads * falloff)
	for e in live_enemies():
		if e == source:
			continue
		var enemy: Enemy = e
		var d2 := enemy.hit_center().distance_to(pos)
		if d2 <= radius:
			enemy.take_damage(int(round(damage * (1.0 - 0.5 * d2 / radius))), pos, 140.0)
	var data: Dictionary = (source as Enemy).data if source is Enemy else {}
	var seconds := float(data.get("puddle_seconds", 30.0))
	var strength := float(data.get("puddle_strength", 2.5))
	if seconds > 0.0 and strength > 0.0:
		add_rad_source(pos, strength, 22.0, seconds, true)
	noise(pos, 120.0)


## A rad source at `pos` (global): `strength` rads/s at its centre falling to 0 at `radius`.
## `seconds` < 0 = permanent. `puddle` draws a glowing puddle that fades out at the end.
func add_rad_source(pos: Vector2, strength: float, radius: float, seconds: float = -1.0,
		puddle: bool = false) -> void:
	var node: Sprite2D = null
	if puddle and ResourceLoader.exists(RAD_PUDDLE_SHEET):
		var sprite := Sprite2D.new()
		sprite.texture = load(RAD_PUDDLE_SHEET)
		sprite.hframes = 4
		sprite.z_index = -8
		add_child(sprite)
		sprite.global_position = pos + Vector2(0, -2)
		node = sprite
	_rad_sources.append({"pos": pos, "strength": strength, "radius": radius,
		"until": _time + seconds if seconds > 0.0 else -1.0, "node": node})


## Rads/second at `pos` from every source here.
func rad_rate_at(pos: Vector2) -> float:
	var total := 0.0
	for s in _rad_sources:
		total += Radiation.source_rate(float(s["strength"]), pos.distance_to(s["pos"]), float(s["radius"]))
	return total


## -- Deaths, loot --

func on_enemy_died(enemy: Node, from: Vector2) -> void:
	var e: Enemy = enemy
	kills += 1
	_add_splat(e.global_position, String(e.data.get("splat", "blood")))
	var loot_table := String(e.data.get("loot", ""))
	var away := (e.global_position - from).normalized()
	for drop in _roll_loot(loot_table, clampi(depth, 1, 4)):
		drop_item(String(drop["item_id"]), int(drop["count"]), e.global_position + Vector2(0, -4), away)
	Events.xp_gained.emit("combat", Combat.kill_xp(int(e.data.get("xp", 5)), depth))
	Events.enemy_killed.emit(e.type)
	enemy_killed.emit(e.type)


## Rolls an enemy's loot table (scripts/loot_db.gd).
func _roll_loot(table_id: String, tier: int) -> Array:
	return LootDB.roll(table_id, tier, _rng) if table_id != "" else []


## Spills `count` of `item_id` into the world as a pickup.
func drop_item(item_id: String, count: int, pos: Vector2, dir: Vector2 = Vector2.ZERO) -> void:
	if _objects != null and _objects.has_method("spawn_pickup"):
		_objects.spawn_pickup(item_id, count, pos, dir)


## A flat ground decal from the level's decor list (remains, bones, cracks, a manhole).
func add_decal(kind: String, pos: Vector2) -> void:
	var sheets := {"remains": ["res://art/env/ruins/remains.png", 1], "bones": ["res://art/env/ruins/bones.png", 2],
		"pavement_decor": ["res://art/env/ruins/pavement_decor.png", 4], "manhole": ["res://art/env/ruins/manhole.png", 2]}
	if not sheets.has(kind):
		return
	var path := String(sheets[kind][0])
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	var frames := int(sheets[kind][1])
	sprite.hframes = frames
	sprite.frame = 0 if kind == "manhole" else _rng.randi_range(0, frames - 1)
	sprite.flip_h = kind != "manhole" and _rng.randf() < 0.5
	sprite.z_index = -9
	add_child(sprite)
	sprite.global_position = pos


func _add_splat(pos: Vector2, kind: String) -> void:
	var path := "res://art/fx/%s_splat.png" % ("ichor" if kind == "ichor" else "blood")
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.hframes = 4
	sprite.frame = _rng.randi_range(0, 3)
	sprite.flip_h = _rng.randf() < 0.5
	sprite.z_index = -8
	add_child(sprite)
	sprite.global_position = pos + Vector2(0, -2)
	_splats.append({"node": sprite, "until": _time + SPLAT_SECONDS})


## -- Tick: combat music, expiring puddles and splats --

func _physics_process(delta: float) -> void:
	frozen = player != null and player.has_method("_in_any_modal") and bool(player.call("_in_any_modal"))
	if frozen:
		return
	_time += delta
	var hunted := false
	for e in live_enemies():
		if (e as Enemy).is_hostile_active():
			hunted = true
			break
	if hunted:
		_combat_linger = COMBAT_LINGER
		_set_combat(true)
	elif _combat_active:
		_combat_linger -= delta
		if _combat_linger <= 0.0:
			_set_combat(false)
	for i in range(_rad_sources.size() - 1, -1, -1):
		var s: Dictionary = _rad_sources[i]
		var node: Sprite2D = s["node"]
		if node != null and is_instance_valid(node):
			node.frame = int(_time * 4.0) % 4
		var until := float(s["until"])
		if until > 0.0:
			if node != null and is_instance_valid(node):
				node.modulate.a = clampf((until - _time) / 3.0, 0.0, 1.0)
			if _time >= until:
				if node != null and is_instance_valid(node):
					node.queue_free()
				_rad_sources.remove_at(i)
	for i in range(_splats.size() - 1, -1, -1):
		var sp: Dictionary = _splats[i]
		if _time >= float(sp["until"]):
			var n: Node2D = sp["node"]
			if is_instance_valid(n):
				n.queue_free()
			_splats.remove_at(i)


func _set_combat(active: bool) -> void:
	if active == _combat_active:
		return
	_combat_active = active
	combat_changed.emit(active)


func combat_active() -> bool:
	return _combat_active


## A cell's spawn point in this node's (= the map's) local space: the cell centre, nudged down
## a little like the player's origin.
func _cell_feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL / 2.0, cell.y * CELL + CELL / 2.0 + 3.0)
