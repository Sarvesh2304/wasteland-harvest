extends PointLight2D
## A warm light that comes on through dusk and goes out at dawn (2026-10-07): lit farmhouse and
## shack windows, town lamp posts, the fire pit. Lights add on top of main.tscn's DayNight
## CanvasModulate, so the settlement glows against the moonlit-blue night instead of the whole
## screen just going dark. Created in code by structures.gd and props.gd via make().

const DUSK_START := 18.0 * 60.0
const DUSK_FULL := 19.75 * 60.0
const DAWN_START := 5.25 * 60.0
const DAWN_END := 6.5 * 60.0
const TEXTURE_SIZE := 96

static var _texture: Texture2D = null

var base_energy := 1.0
var flicker := 0.0
var _t := 0.0
var _night := 0.0


## A light of `color` at `strength`, `radius_scale` x the base texture (96px), optionally
## flickering (0 = steady, ~0.15 = a fire).
static func make(color: Color, strength: float, radius_scale: float, flicker_amount: float = 0.0) -> PointLight2D:
	var light: PointLight2D = (load("res://scripts/night_light.gd") as GDScript).new()
	light.color = color
	light.base_energy = strength
	light.texture_scale = radius_scale
	light.flicker = flicker_amount
	return light


## Pure: how lit the night lights are at `minutes` (0 by day, 1 at night, ramps at dusk/dawn).
static func night_factor(minutes: float) -> float:
	var m := fmod(minutes, 24.0 * 60.0)
	if m >= DUSK_FULL or m < DAWN_START:
		return 1.0
	if m >= DUSK_START:
		return (m - DUSK_START) / (DUSK_FULL - DUSK_START)
	if m < DAWN_END:
		return 1.0 - (m - DAWN_START) / (DAWN_END - DAWN_START)
	return 0.0


func _ready() -> void:
	texture = _light_texture()
	blend_mode = Light2D.BLEND_MODE_ADD
	shadow_enabled = false
	DayManager.time_changed.connect(_on_time_changed)
	_on_time_changed(DayManager.day, DayManager.minutes_into_day)
	set_process(flicker > 0.0)


func _on_time_changed(_day: int, minutes: float) -> void:
	_night = night_factor(minutes)
	enabled = _night > 0.01
	if flicker <= 0.0:
		energy = base_energy * _night


func _process(delta: float) -> void:
	if not enabled:
		return
	_t += delta
	var wobble := sin(_t * 11.0) * 0.5 + sin(_t * 17.3) * 0.3 + sin(_t * 5.1) * 0.2
	energy = base_energy * _night * (1.0 + wobble * flicker)


static func _light_texture() -> Texture2D:
	if _texture != null:
		return _texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55),
		Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = TEXTURE_SIZE
	tex.height = TEXTURE_SIZE
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_texture = tex
	return _texture
