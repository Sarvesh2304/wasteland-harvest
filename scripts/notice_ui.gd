extends CanvasLayer
## The town square's notice board (Milestone B 2026-10-08, docs/SOCIAL_AND_QUESTS.md §5-7). A
## modal like the confirm prompt: built in code by main.gd, registered with the modal gate (the
## clock pauses, the player freezes).
##
## Left: the pinned notes. "Help Wanted" is today's posted request (accept it) or the one you hold
## (progress, days left). "Kael's weather call" gives today's weather and tomorrow's forecast.
## Right: Harlan's Town Works list; the highlighted project shows what it still needs, and
## Contribute puts in whatever you carry toward it.
##
## Keys: up/down pick the note or project, E/Space/Enter accept or contribute, Esc closes.
## Mouse: click a row to pick it, click again (or the action line) to act.

const QuestDB := preload("res://scripts/quest_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const Weather := preload("res://scripts/weather.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const UIText := preload("res://scripts/ui_text.gd")

const CORK := Color("#a8743f")
const CORK_EDGE := Color("#5e3b1c")
const PAPER := Color("#ffedb1")
const PAPER_DIM := Color("#e8d29a")
const TEXT := Color("#281a0b")
const DIM := Color("#6b5a43")
const DONE := Color("#4f7a2b")
const ACCENT := Color("#c5520f")
const BAR_BG := Color("#c9b27a")

const PANEL := Rect2(10, 6, 300, 180)
const LEFT_W := 140.0

signal closed

var active := false
var modal_gate: RefCounted = null
var player: Node = null
var quests: Node = null
var runs_provider: Callable = Callable()
## Milestone D: the market and the caravan, for the TODAY notes (assigned by main.gd).
var market: Node = null
var caravan: Node = null

var _cursor := 0
var _armed := false
var _root: Control = null
var _rows: Array[Control] = []


func _ready() -> void:
	layer = 21
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)


func bind(player_node: Node, quests_node: Node) -> void:
	player = player_node
	quests = quests_node
	quests.changed.connect(func() -> void:
		if active:
			_redraw())


func open() -> bool:
	if active or quests == null:
		return false
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return false
	active = true
	_armed = false
	_cursor = 0
	_root.visible = true
	_redraw()
	Audio.play_sfx("ui_open", -6.0)
	return true


func close() -> void:
	if not active:
		return
	active = false
	_root.visible = false
	Audio.play_sfx("ui_close", -6.0)
	closed.emit()


func _row_count() -> int:
	return 1 + QuestDB.project_ids().size()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if not _armed:
		# The press that opened the board must be released before E acts on it.
		if event.is_action_released("interact") or event.is_action_released("use_tool") \
				or event is InputEventMouseMotion:
			_armed = true
		if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("move_up") \
				or event.is_action_pressed("move_down")):
			return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory"):
		close()
	elif event.is_action_pressed("move_up"):
		_move(-1)
	elif event.is_action_pressed("move_down"):
		_move(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool") \
			or event.is_action_pressed("ui_accept"):
		act()
	get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	_cursor = posmod(_cursor + step, _row_count())
	Audio.play_sfx("ui_hover", -10.0)
	_redraw()


## The highlighted row's action: accept the posted request, or contribute to the project.
func act() -> void:
	var day: int = DayManager.day
	if _cursor == 0:
		if quests.accept(day):
			Audio.play_sfx("ui_confirm", -6.0)
			Events.message.emit("Request accepted: %s" % QuestDB.title_of(quests.active))
		else:
			Audio.play_sfx("tool_whiff", -8.0)
		return
	var id: String = QuestDB.project_ids()[_cursor - 1]
	var took: Dictionary = quests.contribute(id, player, day)
	if took.is_empty():
		Audio.play_sfx("tool_whiff", -8.0)
		Events.message.emit("You're not carrying anything %s needs." % String(QuestDB.project(id)["name"]))
		return
	Audio.play_sfx("coins" if took.has("credits") else "ui_confirm", -4.0)
	var parts: Array[String] = []
	for key in took:
		parts.append("%d Cr" % int(took[key]) if key == "credits" else QuestDB.amount_text(String(key), int(took[key])))
	Events.message.emit("Gave %s." % ", ".join(parts))
	if quests.is_funded(id):
		Events.message.emit("%s is fully funded. Harlan's crew builds it tonight." % String(QuestDB.project(id)["name"]))


## -- View --

func _redraw() -> void:
	for child in _root.get_children():
		child.queue_free()
	_rows.clear()
	_rect(_root, PANEL, CORK_EDGE)
	_rect(_root, PANEL.grow(-2), CORK)
	_text(_root, "NOTICE BOARD", Vector2(PANEL.position.x, PANEL.position.y + 3), PAPER, PANEL.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)
	# The request note shares the left column with Kael's weather call; a project's notice (longer:
	# its story and its reward) takes the whole column.
	if _cursor == 0:
		_build_request_note(Rect2(PANEL.position.x + 6, PANEL.position.y + 15, LEFT_W, 150))
	else:
		_build_project_note(Rect2(PANEL.position.x + 6, PANEL.position.y + 15, LEFT_W, 150),
			QuestDB.project_ids()[_cursor - 1])
	_build_works(Rect2(PANEL.position.x + LEFT_W + 12, PANEL.position.y + 15, PANEL.size.x - LEFT_W - 18, 150))
	var verb := "accept" if _cursor == 0 else "contribute"
	_text(_root, "↑↓ choose   E: %s   Esc: close" % verb,
		Vector2(PANEL.position.x, PANEL.end.y - 12), PAPER, PANEL.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Row 0's note: today's request (take it) or the one you hold (how it's going).
func _build_request_note(r: Rect2) -> void:
	var note := _note(r, 0)
	var w := r.size.x - 12
	var y := 4.0
	_text(note, "HELP WANTED", Vector2(6, y), ACCENT, w)
	y += 12
	var day: int = DayManager.day
	var holding: bool = not quests.active.is_empty()
	var req: Dictionary = quests.active if holding else quests.posted
	if req.is_empty():
		_wrap(note, "Nothing posted today. Check back tomorrow morning.", Vector2(6, y), w, DIM)
		return
	_text(note, QuestDB.title_of(req), Vector2(6, y), TEXT, w)
	y += 12
	var due: int = int(req.get("due_day", day + QuestDB.DUE_DAYS))
	y += _wrap(note, QuestDB.text_for(req, "text", due), Vector2(6, y), w, DIM) + 4
	_text(note, "Reward: %d Cr" % int(req.get("reward", 0)), Vector2(6, y), TEXT, w)
	var status := "E: take this request"
	var status_color := ACCENT
	if holding:
		status = _progress_text(req, day)
		status_color = DONE if _ready_to_hand_in(req) else DIM
		if not quests.posted.is_empty():
			_text(note, "(a new notice is pinned underneath)", Vector2(6, r.size.y - 24), DIM, w)
	_text(note, status, Vector2(6, r.size.y - 13), status_color, w)


## Rows 1-4's note: Harlan's notice for that Town Works project.
func _build_project_note(r: Rect2, id: String) -> void:
	var note := _note(r, -1)
	var w := r.size.x - 12
	var project := QuestDB.project(id)
	_text(note, "TOWN WORKS", Vector2(6, 4), ACCENT, w)
	_text(note, String(project.get("name", id)), Vector2(6, 16), TEXT, w)
	var y := 28.0
	if quests.is_finished(id):
		_wrap(note, String(project.get("done", "")), Vector2(6, y), w, DIM)
		return
	y += _wrap(note, String(project.get("summary", "")), Vector2(6, y), w, DIM) + 5
	_wrap(note, "Reward: " + String(project.get("reward", "")), Vector2(6, y), w, TEXT)


func _progress_text(req: Dictionary, day: int) -> String:
	var left: int = quests.days_left(day)
	var when := "due today" if left <= 0 else ("1 day left" if left == 1 else "%d days left" % left)
	if String(req.get("kind", "")) == "hunt":
		return "%d of %d done, %s" % [int(req.get("progress", 0)), int(req["count"]), when]
	var have: int = int(player.inventory.count_of(String(req["item"]))) if player != null else 0
	if have >= int(req["count"]):
		return "Ready: take it to %s" % DialogueDB.display_name(String(req["npc"]))
	return "Have %d of %d, %s" % [have, int(req["count"]), when]


func _ready_to_hand_in(req: Dictionary) -> bool:
	return String(req.get("kind", "")) == "deliver" and player != null \
		and int(player.inventory.count_of(String(req["item"]))) >= int(req["count"])


## Today's pinned notes, under the Town Works list: Kael's weather call, what Marta's short of
## this week, and when Tully is next at the stall (Milestone D).
func _build_today(pane: Control, at: Vector2, w: float) -> void:
	var y := at.y
	_text(pane, "TODAY", Vector2(at.x, y), ACCENT, w)
	y += 12
	y += _wrap(pane, "%s today, %s tomorrow." % [Weather.display_name(DayManager.weather_today),
		Weather.display_name(DayManager.weather_tomorrow).to_lower()], Vector2(at.x, y), w, TEXT) + 3
	if market != null and not market.demand.is_empty():
		var names: Array[String] = []
		for item_id in market.demand:
			names.append(ItemDB.display_name(String(item_id)))
		y += _wrap(pane, "Marta's short of %s: +40%%." % ", ".join(names), Vector2(at.x, y), w, TEXT) + 3
	if caravan != null:
		var ahead: int = caravan.days_until_next(DayManager.day)
		if ahead == 0:
			_wrap(pane, "Tully's caravan is at the stall.", Vector2(at.x, y), w, DONE)
		elif ahead > 0:
			_wrap(pane, "Tully's caravan: %s." % ("tomorrow" if ahead == 1 else "in %d days" % ahead),
				Vector2(at.x, y), w, DIM)


## The Town Works list and, for the highlighted project, what it still needs.
func _build_works(r: Rect2) -> void:
	var pane := _rect(_root, r, PAPER)
	var w := r.size.x - 12
	_text(pane, "TOWN WORKS", Vector2(6, 4), ACCENT, w)
	var ids := QuestDB.project_ids()
	var y := 16.0
	for i in ids.size():
		var id: String = ids[i]
		var row := _row(pane, Rect2(3, y, r.size.x - 6, 12), i + 1)
		_text(row, String(QuestDB.project(id).get("name", id)), Vector2(3, 2), TEXT, r.size.x - 52)
		if quests.is_finished(id) or quests.is_funded(id):
			_text(row, "Done" if quests.is_finished(id) else "Tonight", Vector2(r.size.x - 46, 2), DONE, 38,
				HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			var p := QuestDB.progress(id, quests.given_to(id))
			_rect(row, Rect2(r.size.x - 44, 5, 36, 4), BAR_BG)
			_rect(row, Rect2(r.size.x - 44, 5, roundf(36.0 * p), 4), DONE)
		y += 13
	y += 4
	if _cursor == 0:
		_build_today(pane, Vector2(6, y), w)
		return
	var id: String = ids[_cursor - 1]
	if quests.is_finished(id):
		_wrap(pane, "Built. " + String(QuestDB.project(id).get("reward", "")), Vector2(6, y), w, DONE)
		return
	if quests.is_funded(id):
		_wrap(pane, "Fully funded. Harlan's crew builds it tonight.", Vector2(6, y), w, DONE)
		return
	_text(pane, "STILL NEEDED", Vector2(6, y), ACCENT, w)
	y += 12
	var given: Dictionary = quests.given_to(id)
	var need := QuestDB.needs(id)
	for item in need:
		var got := mini(int(given.get(item, 0)), int(need[item]))
		var carried: int = int(player.inventory.count_of(item)) if player != null else 0
		var color := DONE if got >= int(need[item]) else (ACCENT if carried > 0 else TEXT)
		_text(pane, ItemDB.display_name(item), Vector2(6, y), color, w - 40)
		_text(pane, "%d/%d" % [got, int(need[item])], Vector2(w - 34, y), color, 40, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 10
	var credits := QuestDB.credits_needed(id)
	if credits > 0:
		var paid := mini(int(given.get("credits", 0)), credits)
		var color := DONE if paid >= credits else (ACCENT if int(player.credits) > 0 else TEXT)
		_text(pane, "Credits", Vector2(6, y), color, w - 40)
		_text(pane, "%d/%d" % [paid, credits], Vector2(w - 54, y), color, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 10
	if y + 12.0 <= r.size.y:
		_text(pane, "Orange: you're carrying some.", Vector2(6, y + 2), DIM, w)


## -- Widgets --

func _note(r: Rect2, row_index: int) -> Control:
	var note: ColorRect = _row(_root, r, row_index) if row_index >= 0 else _rect(_root, r, PAPER)
	note.color = PAPER
	_rect(note, Rect2(r.size.x / 2.0 - 2, -1, 4, 4), CORK_EDGE)  # the pin
	return note


## A selectable area: highlighted with an orange frame when it's the cursor row; click to select,
## click again to act.
func _row(parent: Control, r: Rect2, row_index: int) -> ColorRect:
	var row := _rect(parent, r, PAPER if row_index == 0 else Color(0, 0, 0, 0))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	if row_index == _cursor:
		var frame := Rect2(Vector2(-1, -1), r.size + Vector2(2, 2))
		for edge in [Rect2(frame.position, Vector2(frame.size.x, 1)),
				Rect2(frame.position + Vector2(0, frame.size.y - 1), Vector2(frame.size.x, 1)),
				Rect2(frame.position, Vector2(1, frame.size.y)),
				Rect2(frame.position + Vector2(frame.size.x - 1, 0), Vector2(1, frame.size.y))]:
			_rect(row, edge, ACCENT)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _cursor == row_index:
				act()
			else:
				_cursor = row_index
				Audio.play_sfx("ui_hover", -10.0)
				_redraw.call_deferred())
	_rows.append(row)
	return row


func _rect(parent: Control, r: Rect2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = r.position
	rect.size = r.size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _text(parent: Control, text: String, at: Vector2, color: Color, width: float,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	# Ellipsis first: it's what lets the label be narrower than its text (a size set before it
	# snaps up to the full text width).
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.text = text
	label.position = at
	label.horizontal_alignment = align
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.size = Vector2(width, 10)
	return label


## A wrapped paragraph; returns its height.
func _wrap(parent: Control, text: String, at: Vector2, width: float, color: Color) -> float:
	var label := Label.new()
	label.text = text
	label.position = at
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(width, 10)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	var h := UIText.wrapped_height(label, text, width)
	label.size = Vector2(width, h)
	return h
