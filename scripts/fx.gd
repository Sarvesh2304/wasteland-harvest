extends Node
## Visual feedback helpers (autoload "Fx", 2026-10-07): pixel particle bursts, floating world
## text, camera shake and hit flashes. Everything here is fire-and-forget and frees itself, and
## every call is safe headlessly (it just builds nodes nobody sees).
##
## Particles are small CPUParticles2D one-shots using a 1x1 white texture tinted per preset, so
## they stay pixel-crisp at the game's 4x scale and match the palette.

const PRESETS := {
	# name: [colors, amount, speed_min, speed_max, gravity_y, lifetime, spread_deg, size]
	"dirt": [["#6b4a2c", "#8a6238", "#a87c48"], 9, 25.0, 55.0, 160.0, 0.45, 70.0, 1.0],
	"water": [["#6aa6b8", "#9cc8d2", "#d6ecee"], 10, 20.0, 50.0, 140.0, 0.5, 60.0, 1.0],
	"wood": [["#7b5025", "#9a6631", "#d39a58"], 10, 30.0, 70.0, 180.0, 0.55, 80.0, 1.0],
	"leaves": [["#4a7232", "#5d7d3a", "#7c9a45", "#a0b85a"], 12, 15.0, 45.0, 40.0, 1.1, 120.0, 1.0],
	"leaves_autumn": [["#e88b0f", "#c5520f", "#ffb72d", "#a03c13"], 12, 15.0, 45.0, 40.0, 1.1, 120.0, 1.0],
	"stone": [["#55524b", "#8d877c", "#aaa398"], 9, 30.0, 70.0, 200.0, 0.45, 80.0, 1.0],
	"metal": [["#7d452a", "#a65c30", "#9d9180", "#ddd5c4"], 10, 40.0, 85.0, 200.0, 0.4, 90.0, 1.0],
	"grass": [["#5b9f4c", "#6cb34d", "#8cc75a"], 9, 20.0, 50.0, 120.0, 0.5, 90.0, 1.0],
	"dust": [["#c4995e", "#dcb77a", "#ffedb1"], 8, 8.0, 22.0, -10.0, 0.6, 180.0, 1.0],
	"sparkle": [["#ffc948", "#ffedb1", "#ffffff"], 10, 15.0, 40.0, -20.0, 0.7, 180.0, 1.0],
	"heart": [["#f3acb7", "#e04050", "#ffedb1"], 8, 10.0, 25.0, -30.0, 0.9, 60.0, 1.0],
	"blood": [["#9b1818", "#c43020", "#e84030"], 10, 30.0, 70.0, 200.0, 0.45, 80.0, 1.0],
	"rad": [["#86e83e", "#3fa832", "#ffffff"], 10, 10.0, 30.0, -25.0, 0.9, 180.0, 1.0],
	"smoke": [["#55524b", "#706b62", "#8d877c"], 8, 6.0, 16.0, -18.0, 1.2, 50.0, 2.0],
}

var _pixel: ImageTexture
var _camera: Node = null


func _ready() -> void:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_pixel = ImageTexture.create_from_image(img)


## The node world effects attach to: the current scene (main.tscn's root in play).
func _world_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## A one-shot particle burst. `direction` biases the spray (e.g. away from the player).
func burst(world_pos: Vector2, preset: String, direction: Vector2 = Vector2.UP,
		amount_scale: float = 1.0, parent: Node = null) -> void:
	var cfg: Array = PRESETS.get(preset, PRESETS["dust"])
	var host := parent if parent != null else _world_parent()
	if host == null:
		return
	var p := CPUParticles2D.new()
	p.texture = _pixel
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = maxi(1, int(round(float(cfg[1]) * amount_scale)))
	p.lifetime = float(cfg[5])
	p.direction = direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	p.spread = float(cfg[6])
	p.initial_velocity_min = float(cfg[2])
	p.initial_velocity_max = float(cfg[3])
	p.gravity = Vector2(0, float(cfg[4]))
	p.scale_amount_min = float(cfg[7])
	p.scale_amount_max = float(cfg[7]) + 1.0
	p.z_index = 20
	var ramp := Gradient.new()
	var colors: Array = cfg[0]
	ramp.offsets = PackedFloat32Array()
	ramp.colors = PackedColorArray()
	for i in colors.size():
		ramp.add_point(float(i) / maxf(1.0, float(colors.size() - 1)), Color(colors[i]))
	p.color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.add_point(0.7, Color(1, 1, 1, 1))
	p.color_ramp = fade
	host.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	var t := get_tree().create_timer(p.lifetime + 0.2)
	t.timeout.connect(p.queue_free)


## Text that floats up from a world position and fades (damage numbers, "+3", "Too hard!").
func float_text(world_pos: Vector2, text: String, color: Color = Color("#ffedb1"),
		rise: float = 14.0, seconds: float = 0.9) -> void:
	var host := _world_parent()
	if host == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#281a0b"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 30
	label.size = Vector2(80, 10)
	label.position = world_pos - Vector2(40, 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - rise, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, seconds * 0.5).set_delay(seconds * 0.5)
	tw.chain().tween_callback(label.queue_free)


func reduce_flashes() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings != null and bool(settings.reduce_flashes())


func register_camera(camera: Node) -> void:
	_camera = camera


func shake(intensity: float, duration: float) -> void:
	if _camera != null and is_instance_valid(_camera) and _camera.has_method("shake"):
		_camera.shake(intensity, duration)


## Brief white flash on a CanvasItem (hit feedback). With "Reduce flashes" on (scripts/
## settings.gd) it's a gentle brighten instead of a white-out.
func flash(item: CanvasItem, seconds: float = 0.12) -> void:
	if item == null or not is_instance_valid(item):
		return
	item.modulate = Color(1.5, 1.5, 1.5, 1.0) if reduce_flashes() else Color(3.0, 3.0, 3.0, 1.0)
	var tw := item.create_tween()
	tw.tween_property(item, "modulate", Color.WHITE, seconds)


## A quick horizontal wobble on a node's position (trees/rocks being hit).
func wobble(node: Node2D, strength: float = 1.5, seconds: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base_x := node.position.x
	var tw := node.create_tween()
	tw.tween_property(node, "position:x", base_x + strength, seconds * 0.25)
	tw.tween_property(node, "position:x", base_x - strength * 0.7, seconds * 0.25)
	tw.tween_property(node, "position:x", base_x + strength * 0.3, seconds * 0.25)
	tw.tween_property(node, "position:x", base_x, seconds * 0.25)
