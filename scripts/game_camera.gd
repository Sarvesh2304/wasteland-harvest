extends Camera2D
## Smooth follow camera clamped to map boundaries, with a screen-shake hook (ROADMAP Phase 2).
##
## Deliberately does its own follow + clamp math (rather than Camera2D's built-in
## position_smoothing / limit_* properties) so the exact math the game ships is the math the
## headless test suite exercises (tests/test_camera.gd) — clamp_center() and shake_offset()
## are pure static functions.

## Exponential-decay follow rate: higher = snappier. Frame-rate independent.
@export var follow_speed := 8.0
## Node the camera tracks (set by main.gd; typically the player).
var target: Node2D = null

## World-space rect the view must stay inside (set from the map via set_map_bounds()).
var _map_bounds := Rect2()
var _has_bounds := false

var _shake_intensity := 0.0
var _shake_duration := 0.0
var _shake_time_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	make_current()


func _process(delta: float) -> void:
	if target != null:
		var desired := target.global_position
		# Frame-rate-independent exponential approach.
		var t := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(desired, t)
	if _has_bounds:
		global_position = clamp_center(global_position, _map_bounds, _view_size())
	if _shake_time_left > 0.0:
		_shake_time_left = maxf(_shake_time_left - delta, 0.0)
		var magnitude := shake_offset(_shake_intensity, _shake_duration, _shake_time_left)
		offset = Vector2(
			_rng.randf_range(-magnitude, magnitude),
			_rng.randf_range(-magnitude, magnitude)
		)
	else:
		offset = Vector2.ZERO


## Follow this node from now on (also snaps straight to it — no long pan on spawn).
func set_target(node: Node2D, snap := true) -> void:
	target = node
	if snap and node != null:
		global_position = node.global_position
		if _has_bounds:
			global_position = clamp_center(global_position, _map_bounds, _view_size())


## World-space rect (e.g. TestMap.get_map_rect()) the camera view may never leave.
func set_map_bounds(bounds: Rect2) -> void:
	_map_bounds = bounds
	_has_bounds = true


## Screen-shake hook for future combat (ROADMAP Phase 2): kick the camera with `intensity`
## (max pixel displacement) decaying linearly to zero over `duration` seconds. Nothing calls
## this yet — it exists so Phase 9 combat can, without touching the camera again.
func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = maxf(duration, 0.001)
	_shake_time_left = _shake_duration


## Pure clamp math: keep a camera center inside `bounds` given the visible view size.
## If the map is narrower/shorter than the view on an axis, center on the map instead of
## jittering between two impossible constraints.
static func clamp_center(center: Vector2, bounds: Rect2, view_size: Vector2) -> Vector2:
	var half := view_size * 0.5
	var result := center
	if bounds.size.x <= view_size.x:
		result.x = bounds.position.x + bounds.size.x * 0.5
	else:
		result.x = clampf(center.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= view_size.y:
		result.y = bounds.position.y + bounds.size.y * 0.5
	else:
		result.y = clampf(center.y, bounds.position.y + half.y, bounds.end.y - half.y)
	return result


## Pure decay math for the shake envelope: current max displacement in pixels.
static func shake_offset(intensity: float, duration: float, time_left: float) -> float:
	if duration <= 0.0:
		return 0.0
	return intensity * clampf(time_left / duration, 0.0, 1.0)


func _view_size() -> Vector2:
	return get_viewport_rect().size / zoom
