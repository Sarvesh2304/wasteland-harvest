extends CanvasLayer
## The reel (docs/FISHING.md §4): a line-tension gauge with a green sweet spot, the catch bar
## under it and the fish's silhouette fighting beside them. Built in code from the house palette
## (confirm_ui.gd / menu_screen.gd), readable at 320x192. A modal surface registered with
## main.gd's modal gate like every other (the clock pauses, nothing else can open over it); it
## draws only — scripts/fishing.gd steps the fight (FishDB.reel_step) and feeds update_view().
##
## Accessibility: with Settings' "Reduce flashes" the gauge frame never flashes when the fish
## runs; the steady "RUN!" tag says it instead.

const FishDB := preload("res://scripts/fish_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const HintText := preload("res://scripts/hint_text.gd")

const PANEL_BG := Color("#ffedb1")
const PANEL_EDGE := Color("#7b5025")
const TEXT := Color("#281a0b")
const DIM := Color("#6b5a43")
const ACCENT := Color("#c5520f")
const WARN := Color("#d13b27")
const GAUGE_BG := Color("#3d2a16")
const GAUGE_LOW := Color("#5a3320")
const SWEET := Color("#6f9a3c")
const SWEET_LIT := Color("#95ac49")
const TENSION := Color("#ffc948")
const TENSION_HOT := Color("#e8703a")
const CATCH_FILL := Color("#86b8b0")
const SILHOUETTE := Color("#281a0b")

const WIDTH := 208.0
const HEIGHT := 64.0
const GAUGE_X := 32.0
const GAUGE_W := 168.0
const GAUGE_Y := 17.0
const GAUGE_H := 9.0
const CATCH_Y := 31.0
const CATCH_H := 5.0
## Where the panel sits: under the HUD's clock when the player is low on screen, else above the
## hotbar.
const PANEL_TOP_Y := 36.0
const PANEL_LOW_Y := 104.0

var active := false
var modal_gate: RefCounted = null
## What's on the line (fish id) — the smoke and screenshots read it.
var fish_id := ""

var _box: Control = null
var _title: Label = null
var _run_tag: Label = null
var _hint: Label = null
var _fish: TextureRect = null
var _pips: Array[ColorRect] = []
var _gauge_edge: ColorRect = null
var _low_zone: ColorRect = null
var _sweet: ColorRect = null
var _tension: ColorRect = null
var _marker: ColorRect = null
var _catch_fill: ColorRect = null
var _t := 0.0


func _ready() -> void:
	layer = 21
	_build()
	_box.visible = false
	HintText.follow_device(self, func() -> void:
		if active:
			_hint.text = _hint_text())


## Opens the panel for `id` (named if it's been caught before, else a mystery), on the half of
## the screen away from the player (`player_screen_y`, in 320x192 viewport pixels) so the
## bobber and the water stay in view. False if another modal surface is open.
func open(id: String, known: bool, params: Dictionary, player_screen_y: float = 96.0) -> bool:
	if active:
		return false
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return false
	fish_id = id
	active = true
	_t = 0.0
	_title.text = FishDB.display_name(id) if known else "Fish on the line!"
	_box.position = Vector2(round((320.0 - WIDTH) / 2.0), PANEL_TOP_Y if player_screen_y > 96.0 else PANEL_LOW_Y)
	_fish.texture = _silhouette(id)
	var diff := int(params.get("difficulty", 1))
	for i in _pips.size():
		_pips[i].color = ACCENT if i < diff else Color(DIM, 0.35)
	_hint.text = _hint_text()
	_box.visible = true
	update_view(FishDB.reel_start(params, RandomNumberGenerator.new()), params, false)
	Audio.play_sfx("ui_open", -8.0)
	return true


func close() -> void:
	active = false
	_box.visible = false
	fish_id = ""


## Redraws the gauges for a reel state (FishDB.reel_step's dictionary).
func update_view(state: Dictionary, params: Dictionary, holding: bool) -> void:
	if not active:
		return
	_t += get_physics_process_delta_time()
	var tension := clampf(float(state.get("tension", 0.0)), 0.0, 1.0)
	var band := FishDB.sweet_spot(params, float(state.get("t", 0.0)))
	var in_band := tension >= band.x and tension <= band.y
	_sweet.position.x = GAUGE_X + GAUGE_W * clampf(band.x, 0.0, 1.0)
	_sweet.size.x = GAUGE_W * (clampf(band.y, 0.0, 1.0) - clampf(band.x, 0.0, 1.0))
	_sweet.color = SWEET_LIT if in_band else SWEET
	_tension.size.x = GAUGE_W * tension
	_tension.color = TENSION_HOT if tension > 0.85 else TENSION
	_marker.position.x = GAUGE_X + GAUGE_W * tension - 1.0
	_catch_fill.size.x = (GAUGE_W - 2.0) * clampf(float(state.get("catch", 0.0)), 0.0, 1.0)
	var phase := String(state.get("phase", "rest"))
	var fighting := phase == "run" or phase == "warn"
	_run_tag.visible = phase == "run"
	var flashes_ok := not _reduce_flashes()
	_gauge_edge.color = WARN if phase == "run" and flashes_ok and int(_t * 10.0) % 2 == 0 else PANEL_EDGE
	# The silhouette thrashes on a run, trembles before one, and sways while it rests.
	var shake := 0.0
	if phase == "run":
		shake = 2.0
	elif phase == "warn":
		shake = 1.0
	_fish.position = Vector2(10, 18) + Vector2(sin(_t * (40.0 if fighting else 4.0)) * shake,
		cos(_t * 33.0) * shake * 0.5 + (0.0 if fighting else round(sin(_t * 3.0))))
	_fish.rotation = sin(_t * (25.0 if fighting else 2.0)) * (0.25 if fighting else 0.05)
	_title.add_theme_color_override("font_color", TEXT if not holding else ACCENT)


func _hint_text() -> String:
	var settings := get_node_or_null("/root/Settings")
	var toggle: bool = settings != null and bool(settings.toggle_use())
	return HintText.fill(self, "{use} reel on/off   {back} cut loose" if toggle \
		else "Hold {use} to reel   {back} cut loose")


func _reduce_flashes() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings != null and bool(settings.reduce_flashes())


## -- View --

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.size = Vector2(WIDTH, HEIGHT)
	_box.position = Vector2(round((320.0 - WIDTH) / 2.0), 120.0)
	root.add_child(_box)
	_rect(Vector2.ZERO, _box.size, PANEL_EDGE)
	_rect(Vector2(2, 2), _box.size - Vector2(4, 4), PANEL_BG)
	_title = _label(Vector2(GAUGE_X, 3), TEXT)
	_title.size = Vector2(GAUGE_W - 34.0, 10)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for i in 5:
		_pips.append(_rect(Vector2(GAUGE_X + GAUGE_W - 29.0 + 6.0 * i, 7), Vector2(4, 4), ACCENT))
	_run_tag = _label(Vector2(GAUGE_X + GAUGE_W - 64.0, 3), WARN)
	_run_tag.text = "RUN!"
	_run_tag.size = Vector2(30, 10)
	_run_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_run_tag.visible = false
	# The fish, left of the gauges.
	_fish = TextureRect.new()
	_fish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish.size = Vector2(16, 16)
	_fish.pivot_offset = Vector2(8, 8)
	_fish.position = Vector2(10, 18)
	_box.add_child(_fish)
	# Tension gauge: frame, ground, the "working loose" zone, sweet spot, tension fill, marker.
	_gauge_edge = _rect(Vector2(GAUGE_X - 1.0, GAUGE_Y - 1.0), Vector2(GAUGE_W + 2.0, GAUGE_H + 2.0), PANEL_EDGE)
	_rect(Vector2(GAUGE_X, GAUGE_Y), Vector2(GAUGE_W, GAUGE_H), GAUGE_BG)
	_low_zone = _rect(Vector2(GAUGE_X, GAUGE_Y), Vector2(GAUGE_W * FishDB.LOW_TENSION, GAUGE_H), GAUGE_LOW)
	_sweet = _rect(Vector2(GAUGE_X, GAUGE_Y), Vector2(10, GAUGE_H), SWEET)
	_tension = _rect(Vector2(GAUGE_X, GAUGE_Y + 3.0), Vector2(0, GAUGE_H - 6.0), TENSION)
	_marker = _rect(Vector2(GAUGE_X, GAUGE_Y - 2.0), Vector2(2, GAUGE_H + 4.0), PANEL_BG)
	_rect(Vector2(GAUGE_X + GAUGE_W - 1.0, GAUGE_Y), Vector2(1, GAUGE_H), WARN)  # the snap point
	# Catch bar.
	_rect(Vector2(GAUGE_X - 1.0, CATCH_Y - 1.0), Vector2(GAUGE_W + 2.0, CATCH_H + 2.0), PANEL_EDGE)
	_rect(Vector2(GAUGE_X, CATCH_Y), Vector2(GAUGE_W, CATCH_H), GAUGE_BG)
	_catch_fill = _rect(Vector2(GAUGE_X + 1.0, CATCH_Y + 1.0), Vector2(0, CATCH_H - 2.0), CATCH_FILL)
	var caption := _label(Vector2(6, CATCH_Y + 7.0), DIM)
	caption.text = "Keep the line in the green to land it."
	caption.size = Vector2(WIDTH - 12.0, 10)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _label(Vector2(6, HEIGHT - 14.0), TEXT)
	_hint.size = Vector2(WIDTH - 12.0, 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(r)
	return r


func _label(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	return label


## The fish as a dark silhouette: its icon's alpha in the panel's ink colour, or (until the art
## lands) a code-drawn fish shape.
func _silhouette(id: String) -> Texture2D:
	var path := ItemDB.icon_path(id)
	var img: Image = null
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		img = tex.get_image()
		if img != null:
			img = img.duplicate()
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			for y in img.get_height():
				for x in img.get_width():
					var a := img.get_pixel(x, y).a
					img.set_pixel(x, y, Color(SILHOUETTE, a))
	if img == null:
		img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var big := FishDB.difficulty(id) >= 4
		for x in range(2, 13):
			var half := int(round(sin(float(x - 2) / 10.0 * PI) * (4.0 if big else 3.0)))
			for y in range(8 - half, 8 + half + 1):
				img.set_pixel(x, y, SILHOUETTE)
		for k in 4:  # the tail
			img.set_pixel(13 + mini(k, 2), 8 - k, SILHOUETTE)
			img.set_pixel(13 + mini(k, 2), 8 + k, SILHOUETTE)
		img.set_pixel(5, 7, PANEL_BG)  # an eye
	return ImageTexture.create_from_image(img)
