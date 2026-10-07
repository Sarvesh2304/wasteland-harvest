extends Node2D
## A dropped item lying in the world (2026-10-07): pops out of whatever broke with a little
## bounce, settles, then — Stardew-style — slides into the player once they're close, landing in
## the backpack with a pop sound and a HUD toast. If the backpack is full it stays put and tries
## again periodically, so nothing is ever silently destroyed.
##
## Spawned by scripts/world_objects.gd (and later by combat loot). Finds the player through the
## "player" group, so it needs no wiring.

const ItemDB := preload("res://scripts/item_db.gd")

const MAGNET_RADIUS := 34.0
const COLLECT_RADIUS := 6.0
const SETTLE_SECONDS := 0.45
const GRAVITY := 380.0
const RETRY_SECONDS := 0.6

var item_id := ""
var count := 1

var _velocity := Vector2.ZERO
var _height := 0.0
var _vz := 0.0
var _age := 0.0
var _magnet_speed := 0.0
var _retry_at := 0.0
var _sprite: Sprite2D
var _shadow: Sprite2D
var _collected := false


## Call before adding to the tree. `burst_dir` biases which way it pops out.
func setup(item: String, amount: int, burst_dir: Vector2 = Vector2.ZERO, rng: RandomNumberGenerator = null) -> void:
	item_id = item
	count = amount
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var angle := r.randf_range(-PI, PI)
	var dir := Vector2.from_angle(angle)
	if burst_dir != Vector2.ZERO:
		dir = (dir * 0.6 + burst_dir.normalized() * 0.8).normalized()
	_velocity = dir * r.randf_range(14.0, 34.0)
	_vz = r.randf_range(70.0, 110.0)


func _ready() -> void:
	add_to_group("pickups")
	_shadow = Sprite2D.new()
	_shadow.texture = _shadow_texture()
	_shadow.modulate = Color(0.16, 0.10, 0.04, 0.35)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	var path := ItemDB.icon_path(item_id)
	if path != "" and ResourceLoader.exists(path):
		_sprite.texture = load(path)
		var tex_size := _sprite.texture.get_size()
		if tex_size.x > 16.0:
			_sprite.scale = Vector2(16.0, 16.0) / tex_size
	else:
		_sprite.texture = _fallback_texture()
	_sprite.scale *= 0.75
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	# Bounce phase: simulated height above the ground with gravity, decaying horizontal slide.
	if _height > 0.0 or _vz > 0.0:
		_vz -= GRAVITY * delta
		_height = maxf(0.0, _height + _vz * delta)
		if _height <= 0.0 and _vz < 0.0:
			_vz = -_vz * 0.35 if absf(_vz) > 30.0 else 0.0
	position += _velocity * delta
	_velocity = _velocity.move_toward(Vector2.ZERO, 80.0 * delta)
	_sprite.position = Vector2(0, -4.0 - _height)
	_shadow.scale = Vector2.ONE * clampf(1.0 - _height / 30.0, 0.5, 1.0)
	if _age < SETTLE_SECONDS:
		return
	# Idle bob once settled.
	if _height <= 0.0 and _magnet_speed <= 0.0:
		_sprite.position.y = -4.0 + sin(_age * 4.0) * 0.6
	var player := _player()
	if player == null:
		return
	var to_player: Vector2 = (player.global_position + Vector2(0, -4)) - global_position
	var dist := to_player.length()
	if dist > MAGNET_RADIUS and _magnet_speed <= 0.0:
		return
	if _age < _retry_at:
		return
	if not _has_room(player):
		_retry_at = _age + RETRY_SECONDS
		_magnet_speed = 0.0
		return
	_magnet_speed = minf(_magnet_speed + 520.0 * delta, 220.0)
	global_position += to_player.normalized() * minf(_magnet_speed * delta, dist)
	if dist <= COLLECT_RADIUS:
		_collect(player)


func _player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


func _has_room(player: Node) -> bool:
	if not ("inventory" in player):
		return false
	# Partial collection is fine: one unit of room is enough to start pulling it in.
	return player.inventory.can_add(item_id, 1)


func _collect(player: Node) -> void:
	var leftover: int = player.inventory.add_item(item_id, count)
	var added := count - leftover
	if added <= 0:
		_retry_at = _age + RETRY_SECONDS
		return
	count -= added
	Events.item_gained.emit(item_id, added)
	Audio.play_sfx("pickup", -2.0, 0.08)
	if count <= 0:
		_collected = true
		queue_free()


func _shadow_texture() -> Texture2D:
	var img := Image.create(8, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(1, 7):
		img.set_pixel(x, 1, Color.WHITE)
	for x in range(2, 6):
		img.set_pixel(x, 0, Color.WHITE)
		img.set_pixel(x, 2, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _fallback_texture() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color("#ffc948"))
	return ImageTexture.create_from_image(img)
