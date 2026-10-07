extends Node2D
## The target-tile highlight (2026-10-07): soft corner brackets on the cell the player's next
## action lands on, so aiming is never a guess. Bright when pressing would do something, warning
## amber when it can't ("Too tough", "Wrong season", "Empty"), faint otherwise. Also keeps the
## latest describe_action() result for the HUD's button prompts.

const CELL := 16.0
const COLOR_ACTIVE := Color("#ffedb1")
const COLOR_WARN := Color("#ffb72d")
const COLOR_IDLE := Color(1.0, 1.0, 1.0, 0.22)
const WARN_VERBS := ["Too tough", "Wrong season", "Empty"]

var actions: Dictionary = {"use": "", "interact": ""}
var _player: Node = null
var _cell := Vector2i(-9999, -9999)
var _refresh_left := 0.0
var _pulse := 0.0


func bind(player: Node) -> void:
	_player = player
	z_index = 40


func _process(delta: float) -> void:
	_pulse += delta
	_refresh_left -= delta
	if _player == null or _player.test_map == null:
		visible = false
		return
	var hidden: bool = _player._in_any_modal() or _player._in_build_mode() or _player._zone_transitioning
	visible = not hidden
	if hidden:
		return
	var cell: Vector2i = _player.target_cell()
	if cell != _cell or _refresh_left <= 0.0:
		_cell = cell
		_refresh_left = 0.12
		actions = _player.describe_action()
		global_position = _player.test_map.get_global_cell_center(cell) - Vector2(CELL, CELL) * 0.5
	queue_redraw()


func _draw() -> void:
	var verb := String(actions.get("use", ""))
	if verb == "":
		verb = String(actions.get("interact", ""))
	var color := COLOR_IDLE
	if verb != "":
		color = COLOR_WARN if WARN_VERBS.has(verb) else COLOR_ACTIVE
		color.a = 0.75 + 0.25 * sin(_pulse * 5.0)
	var inset := 0.0 if verb == "" else -0.5 + 0.5 * sin(_pulse * 5.0)
	var a := Vector2(inset, inset)
	var b := Vector2(CELL - inset, CELL - inset)
	var l := 4.0
	# Four L-shaped corners (1px lines on the pixel grid).
	for corner in [[a, Vector2(1, 0), Vector2(0, 1)], [Vector2(b.x, a.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(a.x, b.y), Vector2(1, 0), Vector2(0, -1)], [b, Vector2(-1, 0), Vector2(0, -1)]]:
		var p: Vector2 = corner[0]
		draw_line(p, p + corner[1] * l, color, 1.0)
		draw_line(p, p + corner[2] * l, color, 1.0)
