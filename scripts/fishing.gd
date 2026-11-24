extends Node2D
## Fishing, live (2026-11-24, docs/FISHING.md). One instance under Main (built by main.gd), at the
## world origin so its children draw in world coordinates. Owns the cast (charge meter, the rod
## in hand, the bobber's flight), the wait (nibbles, the bite, the hook window), junk, the reel
## (scripts/fishing_reel_ui.gd, a modal registered with main.gd's modal gate) and the catch log
## (saved as the additive "fishing" section). The rules — what bites, when, and the reel's
## physics — are scripts/fish_db.gd's pure functions.
##
## Input: player.gd hands over every physics frame (handle_player_frame) with its Use state —
## the same toggle-aware _use_pressed() every tool reads, so Settings' "tap to start/stop" mode
## works here too (a tap stands in for a hold: tap to charge, tap to cast, tap to hook, tap to
## start and stop reeling) — and the move vector. Use and Esc/B (ui_cancel) are the only
## buttons fishing needs, so a pad plays it exactly like a keyboard.
##
##   IDLE --Use with the rod--> CHARGING --release--> CASTING --lands--> WAITING
##   WAITING --bite--> BITE --Use within 0.75 s--> REELING (or junk: caught at once) --> IDLE
## Moving, Esc/B, another screen opening, a zone change or a new day reels in at any point.

signal caught_fish(fish_id: String)
signal changed

const FishDB := preload("res://scripts/fish_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const ReelUIScript := preload("res://scripts/fishing_reel_ui.gd")

enum State { IDLE, CHARGING, CASTING, WAITING, BITE, REELING }

const ROD_ID := "fishing_rod"
const BOBBER_ART := "res://art/fx/bobber.png"
const SPLASH_ART := "res://art/fx/splash.png"
const ALERT_ART := "res://art/fx/alert_mark.png"
const ROD_ART := "res://art/items/fishing_rod.png"
const LINE_COLOR := Color("#e8e2d2", 0.85)
const METER_BG := Color("#281a0b")
const METER_FILL := Color("#ffc948")
const METER_FULL := Color("#95ac49")
const RIPPLE_COLOR := Color("#cfe3e6")
const CAST_FLIGHT_SECONDS := 0.4
const NIBBLE_SECONDS := 0.18

## The catch log (saved): {fish_id: count}, and whether the Old Mayor has been landed.
var caught: Dictionary = {}
var old_mayor := false
var state: int = State.IDLE
var rng := RandomNumberGenerator.new()
## Test hook: the next bite is this pick ({"kind": "fish", "id": ...} / a junk entry) instead of a roll.
var forced_pick: Dictionary = {}
## Test hook: bite after this many seconds instead of the rolled delay (< 0 = roll).
var forced_bite_seconds := -1.0

var main: Node = null
var player: Node = null
var reel_ui: CanvasLayer = null

var power := 0.0
var _charge_t := 0.0
var _map: Node = null
var _water := ""
var _target_cell := Vector2i.ZERO
var _bobber_at := Vector2.ZERO
var _wait_t := 0.0
var _bite_at := 0.0
var _nibbles: Array[float] = []
var _nibble_until := -1.0
var _bite_left := 0.0
var _pick: Dictionary = {}
var _reel_state: Dictionary = {}
var _reel_params: Dictionary = {}
var _use_last := false
var _need_release := false
var _ripples: Array = []  # [age, strength]
var _t := 0.0

var _bobber: Sprite2D = null
var _line: Line2D = null
var _rod: Sprite2D = null
var _alert: Sprite2D = null
var _meter: Node2D = null


func _ready() -> void:
	rng.randomize()
	z_index = -5
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = LINE_COLOR
	_line.z_index = 6  # over the player: the line leaves the rod tip in front of them
	_line.z_as_relative = false
	_line.visible = false
	add_child(_line)
	_bobber = Sprite2D.new()
	_bobber.texture = _bobber_texture()
	_bobber.hframes = 2
	_bobber.visible = false
	add_child(_bobber)


## Wired by main.gd: the player, the modal gate and the reel panel.
func setup(main_node: Node) -> void:
	main = main_node
	player = main.player
	reel_ui = ReelUIScript.new()
	reel_ui.name = "FishingReelUI"
	main.add_child(reel_ui)
	DayManager.day_started.connect(func(_day: int) -> void: cancel())
	_rod = Sprite2D.new()
	_rod.name = "FishingRod"
	_rod.texture = load(ROD_ART) if ResourceLoader.exists(ROD_ART) else null
	_rod.visible = false
	player.add_child(_rod)
	_alert = Sprite2D.new()
	_alert.name = "BiteAlert"
	_alert.texture = load(ALERT_ART) if ResourceLoader.exists(ALERT_ART) else null
	_alert.position = Vector2(0, -27)
	_alert.z_index = 8
	_alert.visible = false
	player.add_child(_alert)
	_meter = Node2D.new()
	_meter.name = "CastMeter"
	_meter.z_index = 8
	_meter.visible = false
	_meter.draw.connect(_draw_meter)
	player.add_child(_meter)


## -- Queries --

func busy() -> bool:
	return state != State.IDLE


func reeling() -> bool:
	return state == State.REELING


func count_of(fish_id: String) -> int:
	return int(caught.get(fish_id, 0))


func species_caught() -> int:
	return FishDB.species_caught(caught)


func total_caught() -> int:
	var n := 0
	for id in caught:
		n += int(caught[id])
	return n


## has_fished / angler / caught_old_mayor for main.gd's dialogue_context.
func flags() -> Dictionary:
	return FishDB.flags_for(caught, old_mayor)


## What Use does right now, for the HUD prompt while a line is out.
func prompt_actions() -> Dictionary:
	match state:
		State.CHARGING:
			var settings := get_node_or_null("/root/Settings")
			var toggle: bool = settings != null and bool(settings.toggle_use())
			return {"use": "Cast" if toggle else "Cast (let go)", "interact": ""}
		State.CASTING, State.WAITING:
			return {"use": "Reel in", "interact": ""}
		State.BITE:
			return {"use": "Hook it!", "interact": ""}
	return {"use": "", "interact": ""}


## -- Starting a cast (player.gd's use_tool, with the rod in hand) --

## Begins charging a cast. False while the last catch's press is still held, or mid-cast.
func try_start() -> bool:
	if state != State.IDLE or _need_release or player == null or player.test_map == null:
		return false
	state = State.CHARGING
	_charge_t = 0.0
	power = 0.0
	_map = player.test_map
	_show_rod(true)
	_meter.visible = true
	Audio.play_sfx("tool_charge", -8.0)
	changed.emit()
	return true


## -- The per-frame hand-over from player.gd --

## Called by player.gd every physics frame with its Use state (toggle-aware), the move vector
## and whether one of its own modal screens is open. True = fishing owns this frame (the player
## stands still and does nothing else).
func handle_player_frame(use_pressed: bool, move: Vector2, modal_open: bool) -> bool:
	var pressed_edge := use_pressed and not _use_last
	_use_last = use_pressed
	if state == State.IDLE:
		if _need_release and not use_pressed:
			_need_release = false
		return false
	if not _still_valid() or (modal_open and state != State.REELING):
		cancel()
		return false
	var cancel_pressed := Input.is_action_just_pressed("ui_cancel")
	match state:
		State.CHARGING:
			if cancel_pressed:
				cancel()
				return true
			if move != Vector2.ZERO:
				player.facing = player.facing_from_input(move, player.facing)
				player._play("idle")
				_show_rod(true)
			if not use_pressed:
				_cast()
		State.CASTING, State.WAITING:
			if cancel_pressed or move != Vector2.ZERO:
				_reel_in_empty("")
			elif pressed_edge:
				_reel_in_empty("Just a nibble." if _wait_t < _nibble_until else "")
		State.BITE:
			if pressed_edge:
				_hook()
			elif cancel_pressed or move != Vector2.ZERO:
				_reel_in_empty("It got away.")
		State.REELING:
			if cancel_pressed:
				_end_reel("let_go")
			else:
				_reel_held = use_pressed
	return true


var _reel_held := false


func _still_valid() -> bool:
	if player == null or not is_instance_valid(player) or player.dead or player._zone_transitioning:
		return false
	if player.test_map != _map:
		return false
	return String(player.inventory.get_selected_slot().get("item_id", "")) == ROD_ID or state == State.REELING


## -- The loop --

func _physics_process(delta: float) -> void:
	_t += delta
	_age_ripples(delta)
	match state:
		State.CHARGING:
			_charge_t += delta
			power = clampf(_charge_t / FishDB.CHARGE_SECONDS, 0.0, 1.0)
			if _rod != null:
				_rod.rotation = _rod_sign() * -0.6 * power
			_meter.queue_redraw()
		State.WAITING:
			_wait_t += delta
			_update_bobber_idle()
			if not _nibbles.is_empty() and _wait_t >= _nibbles[0]:
				_nibbles.pop_front()
				_nibble()
			if _wait_t >= _bite_at:
				_bite()
		State.BITE:
			_bite_left -= delta
			_bobber.frame = 1
			_bobber.position = _bobber_at + Vector2(rng.randf_range(-0.6, 0.6), 2.0)
			if _bite_left <= 0.0:
				_reel_in_empty("It got away.")
		State.REELING:
			var before := String(_reel_state.get("phase", ""))
			_reel_state = FishDB.reel_step(_reel_state, _reel_params, _reel_held, delta, rng)
			if String(_reel_state.get("phase", "")) == "run" and before != "run":
				Audio.play_sfx("water", -10.0, 0.15)
				_ripple(1.0)
			reel_ui.update_view(_reel_state, _reel_params, _reel_held)
			_bobber.position = _bobber_at + Vector2(sin(_t * 30.0) * float(_reel_state["tension"]), 1.0)
			if _rod != null:
				_rod.rotation = _rod_sign() * (0.25 + 0.35 * float(_reel_state["tension"]))
			var result := String(_reel_state.get("result", ""))
			if result != "":
				_end_reel(result)
	_update_line()
	queue_redraw()


## -- Cast --

func _cast() -> void:
	_meter.visible = false
	var dir: Vector2 = player.FACING_VECTORS.get(player.facing, Vector2.DOWN)
	var my_cell: Vector2i = _map.world_to_cell(player.global_position)
	var cells := FishDB.cast_cells(power)
	_target_cell = my_cell + Vector2i(dir) * cells
	player._swing()  # the tool-swing animation, with the rod in hand
	Audio.play_sfx("swing", -6.0, 0.1)
	if String(_map.terrain_at(_target_cell)) != "W":
		_finish()
		Fx.float_text(player.global_position + Vector2(0, -22), "No water there", Color("#ffedb1"))
		return
	_water = String(_map.water_kind_at(_target_cell))
	player.set_energy(player.energy - FishDB.CAST_ENERGY * player._skill_multiplier(ROD_ID))
	if player.dead or state == State.IDLE:
		return
	state = State.CASTING
	_bobber_at = _map.get_global_cell_center(_target_cell) + Vector2(0, -1)
	var from := _rod_tip()
	_bobber.visible = true
	_bobber.frame = 0
	_bobber.position = from
	_line.visible = true
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		_bobber.position = from.lerp(_bobber_at, k) + Vector2(0, -sin(k * PI) * (10.0 + 4.0 * float(cells))),
		0.0, 1.0, CAST_FLIGHT_SECONDS)
	tw.tween_callback(_landed)


func _landed() -> void:
	if state != State.CASTING:
		return
	_bobber.position = _bobber_at
	_splash(_bobber_at)
	Audio.play_sfx_at("splash", _bobber_at, -4.0)
	player.using_tool = false  # the swing is cut short by the landing: release its lock
	player.sprite.speed_scale = 1.0
	player._play("idle")
	state = State.WAITING
	_wait_t = 0.0
	_bite_at = forced_bite_seconds if forced_bite_seconds >= 0.0 \
		else FishDB.bite_delay(rng, String(DayManager.weather_today), float(DayManager.minutes_into_day))
	_nibbles = FishDB.nibble_times(rng, _bite_at)
	_nibble_until = -1.0
	if _water == "":
		_bite_at = INF  # dead water: the bobber just sits there (the HUD says so)
		Events.message.emit("Nothing lives in this water.")
	changed.emit()


func _update_bobber_idle() -> void:
	var dipping := _wait_t < _nibble_until
	_bobber.frame = 1 if dipping else 0
	_bobber.position = _bobber_at + Vector2(0, (1.0 if dipping else 0.0) + round(sin(_t * 3.0) * 0.6))


func _nibble() -> void:
	_nibble_until = _wait_t + NIBBLE_SECONDS
	Audio.play_sfx_at("water", _bobber_at, -16.0, 0.2)
	_ripple(0.4)


func _bite() -> void:
	_pick = forced_pick.duplicate() if not forced_pick.is_empty() else FishDB.pick(_water,
		DayManager.season(), float(DayManager.minutes_into_day), String(DayManager.weather_today), rng, old_mayor)
	forced_pick = {}
	if _pick.is_empty():
		_bite_at = INF
		return
	state = State.BITE
	_bite_left = FishDB.HOOK_WINDOW
	_bobber.frame = 1
	Audio.play_sfx("fish_bite", -2.0, 0.05)
	_ripple(1.0)
	_alert.visible = _alert.texture != null
	_alert.scale = Vector2(0.4, 0.4)
	var tw := _alert.create_tween()
	tw.tween_property(_alert, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _alert.texture == null:
		Fx.float_text(player.global_position + Vector2(0, -24), "!", Color("#ffc948"), 6.0, 0.6)
	changed.emit()


func _hook() -> void:
	_alert.visible = false
	if String(_pick.get("kind", "")) == "junk":
		_land_junk()
		return
	var id := String(_pick.get("id", ""))
	_reel_params = FishDB.reel_params(FishDB.difficulty(id), _foraging_level())
	_reel_state = FishDB.reel_start(_reel_params, rng)
	_reel_held = _use_last
	var screen_y: float = player.get_global_transform_with_canvas().origin.y
	if not reel_ui.open(id, count_of(id) > 0, _reel_params, screen_y):
		_reel_in_empty("")
		return
	state = State.REELING
	Audio.play_sfx("swing", -8.0)
	changed.emit()


## -- Endings --

func _land_junk() -> void:
	var item := String(_pick.get("item", ""))
	var n := int(_pick.get("count", 1))
	_give(item, n)
	Events.xp_gained.emit("foraging", FishDB.JUNK_XP)
	Events.message.emit(String(_pick.get("line", "Junk.")))
	Audio.play_sfx("scrap", -6.0)
	_splash(_bobber_at)
	_finish()


func _end_reel(result: String) -> void:
	reel_ui.close()
	var id := String(_pick.get("id", ""))
	match result:
		"caught":
			_land_fish(id)
			return
		"snap":
			Audio.play_sfx("tool_whiff", -2.0)
			Events.message.emit("The line snapped. The fish is gone; the rod's fine.")
		"escape":
			Events.message.emit("It slipped the hook.")
		_:
			Events.message.emit("You let it go.")
	_splash(_bobber_at)
	_finish()


func _land_fish(id: String) -> void:
	var first := count_of(id) == 0
	caught[id] = count_of(id) + 1
	if FishDB.is_legendary(id):
		old_mayor = true
	_give(id, 1)
	Events.xp_gained.emit("foraging", FishDB.catch_xp(id))
	Audio.play_sfx("splash", -4.0)
	Audio.play_sfx("achievement" if first or FishDB.is_legendary(id) else "pickup", -4.0)
	_splash(_bobber_at)
	Fx.float_text(player.global_position + Vector2(0, -24), FishDB.display_name(id) + "!", Color("#ffc948"))
	Fx.burst(player.global_position + Vector2(0, -10), "sparkle", Vector2.UP, 0.6)
	if first and not FishDB.is_legendary(id):
		Events.message.emit("New catch: %s. (Journal, Fish page)" % FishDB.display_name(id))
	caught_fish.emit(id)
	_finish()
	if FishDB.is_legendary(id) and main != null and main.confirm_ui != null:
		main.confirm_ui.show_text("The Old Mayor",
			"Sixty years of Harlan's grandfather's stories, and every word of them true. The biggest catfish anyone has ever seen, and he's yours. The whole town will hear about this.")
	changed.emit()


func _give(item_id: String, n: int) -> void:
	if item_id == "" or n <= 0:
		return
	var left: int = player.inventory.add_item(item_id, n)
	if n - left > 0:
		Events.item_gained.emit(item_id, n - left)
	if left > 0 and player.objects != null:
		player.objects.spawn_pickup(item_id, left, player.global_position)


func _reel_in_empty(message: String) -> void:
	if message != "":
		Fx.float_text(player.global_position + Vector2(0, -22), message, Color("#ffedb1"))
	Audio.play_sfx("water", -12.0, 0.2)
	_finish()


## Reels in and stops wherever things were (a new day, a zone change, another screen). Safe to
## call when idle.
func cancel() -> void:
	if state == State.IDLE:
		return
	if reel_ui != null and reel_ui.active:
		reel_ui.close()
	_finish()


func _finish() -> void:
	state = State.IDLE
	_need_release = true
	_pick = {}
	_reel_state = {}
	_bite_at = 0.0
	_nibbles.clear()
	if _meter != null:
		_meter.visible = false
	if _alert != null:
		_alert.visible = false
	_bobber.visible = false
	_line.visible = false
	_show_rod(false)
	if player != null and is_instance_valid(player):
		# A release is needed before the next cast, in either use mode (the toggle latch included).
		player._use_latched = false
		if player.using_tool and not player.sprite.is_playing():
			player.using_tool = false
	changed.emit()


## -- Visuals --

func _foraging_level() -> int:
	return int(main.skills.level("foraging")) if main != null and main.skills != null else 0


func _rod_sign() -> float:
	return -1.0 if player.facing == "west" else 1.0


func _show_rod(on: bool) -> void:
	if _rod == null:
		return
	_rod.visible = on and _rod.texture != null
	if not on:
		return
	match String(player.facing):
		"west":
			_rod.flip_h = true
			_rod.position = Vector2(-6, -9)
			_rod.z_index = 1
		"north":
			_rod.flip_h = false
			_rod.position = Vector2(5, -13)
			_rod.z_index = -1
		"south":
			_rod.flip_h = false
			_rod.position = Vector2(6, -7)
			_rod.z_index = 1
		_:
			_rod.flip_h = false
			_rod.position = Vector2(6, -9)
			_rod.z_index = 1
	_rod.rotation = 0.0


## The rod tip in world space (the icon's top corner, turned with the rod).
func _rod_tip() -> Vector2:
	if _rod == null or not _rod.visible:
		return player.global_position + Vector2(0, -12)
	var local := Vector2(-5.5 if _rod.flip_h else 5.5, -6.5)
	return _rod.global_transform * local


func _update_line() -> void:
	if not _line.visible:
		return
	var a := _rod_tip()
	var b := _bobber.position + Vector2(0, -2)
	var slack := 4.0 if state == State.WAITING else (1.0 if state == State.REELING else 2.0)
	var mid := (a + b) * 0.5 + Vector2(0, slack)
	_line.points = PackedVector2Array([a, mid, b])


func _splash(at: Vector2) -> void:
	if ResourceLoader.exists(SPLASH_ART):
		var s := Sprite2D.new()
		s.texture = load(SPLASH_ART)
		s.hframes = 3
		s.position = at + Vector2(0, -4)
		s.z_index = 1
		add_child(s)
		var tw := s.create_tween()
		tw.tween_property(s, "frame", 2, 0.3)
		tw.tween_callback(s.queue_free)
	else:
		Fx.burst(at, "water", Vector2.UP, 0.8)
	_ripple(0.8)


func _ripple(strength: float) -> void:
	_ripples.append([0.0, strength])


func _age_ripples(delta: float) -> void:
	for r in _ripples:
		r[0] = float(r[0]) + delta
	_ripples = _ripples.filter(func(r) -> bool: return float(r[0]) < 0.9)


func _draw() -> void:
	if not _bobber.visible:
		return
	for r in _ripples:
		var age := float(r[0])
		var k := age / 0.9
		var c := RIPPLE_COLOR
		c.a = (1.0 - k) * 0.7 * float(r[1])
		draw_arc(_bobber_at + Vector2(0, 1), 2.0 + k * 7.0 * float(r[1]), 0.0, TAU, 16, c, 1.0)
	if state == State.WAITING or state == State.BITE:
		var c2 := RIPPLE_COLOR
		c2.a = 0.35
		draw_arc(_bobber_at + Vector2(0, 2), 3.5 + sin(_t * 3.0) * 0.5, 0.0, TAU, 12, c2, 1.0)


## The cast meter over the player's head: a 16x3 bar filling over a second.
func _draw_meter() -> void:
	var at := Vector2(-8, -26)
	_meter.draw_rect(Rect2(at - Vector2(2, 2), Vector2(20, 7)), Color("#ffedb1"))
	_meter.draw_rect(Rect2(at - Vector2(1, 1), Vector2(18, 5)), METER_BG)
	_meter.draw_rect(Rect2(at, Vector2(16.0 * power, 3)), METER_FULL if power >= 1.0 else METER_FILL)


## The bobber sheet (16x8: float, dip). Until art/fx/bobber.png exists, a code-drawn stand-in
## in the same layout.
func _bobber_texture() -> Texture2D:
	if ResourceLoader.exists(BOBBER_ART):
		return load(BOBBER_ART)
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var red := Color("#d13b27")
	var cream := Color("#ffedb1")
	var dark := Color("#281a0b")
	for frame in 2:
		var ox := frame * 8
		var oy := 2 if frame == 0 else 4
		for y in 4:
			for x in 4:
				var edge := (x == 0 or x == 3) and (y == 0 or y == 3)
				if edge:
					continue
				var col := red if y < 2 else cream
				if frame == 1 and y >= 2:
					continue  # dipped: only the red cap shows above the water
				img.set_pixel(ox + 2 + x, oy + y, col)
		img.set_pixel(ox + 3, oy - 1, dark)
		img.set_pixel(ox + 4, oy - 1, dark)
	return ImageTexture.create_from_image(img)


## -- Save --

func save_state() -> Dictionary:
	return {"caught": caught.duplicate(), "old_mayor": old_mayor}


func load_state(data: Dictionary) -> void:
	var entry := FishDB.decode_log(data)
	caught = entry["caught"]
	old_mayor = bool(entry["old_mayor"])
	changed.emit()

