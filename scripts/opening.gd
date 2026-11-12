extends Control
## The New Game opening (Milestone E, GDD.md §3 "The birth/intro sequence"):
##
##   settlement picker -> [OFFER] -> INTRO -> CREATE -> MONTAGE -> scenes/main.tscn (day 1)
##
##   OFFER    only when this player has seen the intro before (GameState.has_seen_opening()):
##            "Skip to the birth" (default) or "Watch the story".
##   INTRO    three illustrated pages — the parents staking their claim, the first walls going
##            up, a birth in the one-room clinic.
##   CREATE   scripts/character_creator.gd at the birth moment: name, pronouns, look.
##   MONTAGE  four pages compressing two decades: growing up as the town grows, the parents'
##            peaceful passing, the farm passing to you — then day 1 begins.
##
## Illustrations are code-generated pixel art (tools/art/opening/, art/opening/*.png). Page
## text may use {settlement}, {name}, {them}, {their}, {child} (filled from GameState and the
## chosen pronouns) — fill_page_text() is pure and unit-tested.
##
## Input uses existing actions only (a controller drives all of it):
##   pages:  use_tool / move_right = next (the first press finishes a still-typing caption),
##           move_left = previous, ui_cancel = skip the rest of the intro (to creation) or of
##           the montage (to day 1).
##   offer:  move_up/move_down choose, use_tool confirms, ui_cancel = skip to the birth.
##   create: forwarded to the creator (see its doc).
## Reaching day 1 marks the opening as seen (GameState.mark_opening_seen()).

const PlayerProfile := preload("res://scripts/player_profile.gd")
const HintText := preload("res://scripts/hint_text.gd")
const SettlementDB := preload("res://scripts/settlement_db.gd")
const CreatorScript := preload("res://scripts/character_creator.gd")
const PlayerLook := preload("res://scripts/player_look.gd")
const PLAYER_FRAMES := preload("res://art/characters/player/player_frames.tres")

const MAIN_SCENE := "res://scenes/main.tscn"
const ART_DIR := "res://art/opening/"

const INTRO_PAGES: Array[Dictionary] = [
	{"art": "claim", "text": "Twenty-five years after the war, two young scavengers drove a stake into the dust at {settlement}, and decided to stay."},
	{"art": "walls", "text": "Neighbours came. The first walls went up by hand, plank by salvaged plank, around a well, a store and a one-room clinic."},
	{"art": "clinic", "text": "And one night that first winter, by the clinic's lamplight, a young Doc Ama laid a squalling baby in your mother's arms."},
]
const MONTAGE_PAGES: Array[Dictionary] = [
	{"art": "childhood", "text": "You grew up underfoot: in the fields, in Marta's store, at the gate where Kael kept sending you home. The town grew up around you."},
	{"art": "town", "text": "Twenty years went by in seasons. New roofs, new neighbours, a fence around everything that mattered."},
	{"art": "farewell", "text": "This spring your parents passed, a week apart, peacefully and of old age, in the town they built. Everyone came to say goodbye."},
	# "player": the live player sprite, in the look just chosen, drawn onto the picture at
	# [x, bottom, animation] (picture pixels; tools/art/opening/op_pages.py PLAYER_SPOTS leaves
	# that spot clear).
	{"art": "farm", "player": [140, 104, "idle_north"], "text": "The farm is yours now, {name}. The fields have gone wild and the tools are worn, but the whole town knows whose child you are."},
]

const OFFER_SKIP := "Skip to the birth"
const OFFER_WATCH := "Watch the story"

const TEXT_COLOR := Color("#ffedb1")
const HINT_COLOR := Color("#9d9180")
const TITLE_COLOR := Color("#ffc948")
const ROW_COLOR := Color("#7b5025")
const ROW_SELECTED_COLOR := Color("#c5520f")
const FRAME_COLOR := Color("#b77c3e")
const FRAME_DARK := Color("#7b5025")
const BG_COLOR := Color("#281a0b")
const DOT_ACTIVE := Color("#ffc948")
const DOT_INACTIVE := Color("#7b5025")

const PICTURE_RECT := Rect2(32, 8, 256, 112)
const CAPTION_RECT := Rect2(20, 126, 280, 40)
const REVEAL_SECONDS := 1.2
const FADE_SECONDS := 0.35

enum Mode { OFFER, INTRO, CREATE, MONTAGE, DONE }

var mode: Mode = Mode.INTRO
var page_index := 0
var offer_index := 0
var creator: Control = null

var _picture: TextureRect
var _picture_frame: Control
var _caption: Label
var _hint: Label
var _dots: HBoxContainer
var _offer_panel: Control
var _offer_rows: Array[Label] = []
var _reveal_tween: Tween
var _page_player: AnimatedSprite2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if GameState.has_seen_opening():
		_show_offer()
	else:
		_show_page(Mode.INTRO, 0)


func _unhandled_input(event: InputEvent) -> void:
	handle_input(event)


## Public so tools/opening_smoke.gd can drive the real input path with synthetic events.
func handle_input(event: InputEvent) -> void:
	match mode:
		Mode.OFFER:
			_offer_input(event)
		Mode.INTRO, Mode.MONTAGE:
			_page_input(event)
		Mode.CREATE:
			if creator != null:
				creator.handle_input(event)
	if event.is_pressed() and is_inside_tree():
		get_viewport().set_input_as_handled()


## -- Pages --

func pages_for(m: Mode) -> Array[Dictionary]:
	return INTRO_PAGES if m == Mode.INTRO else MONTAGE_PAGES


func _page_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		skip()
	elif event.is_action_pressed("use_tool") or event.is_action_pressed("move_right") \
			or _is_enter(event):
		advance()
	elif event.is_action_pressed("move_left"):
		if page_index > 0:
			_show_page(mode, page_index - 1)


func _is_enter(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
		and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER)


## Next page; the first press on a caption that is still revealing just finishes it.
func advance() -> void:
	if _caption.visible_ratio < 1.0:
		if _reveal_tween != null:
			_reveal_tween.kill()
		_caption.visible_ratio = 1.0
		return
	if page_index + 1 < pages_for(mode).size():
		_show_page(mode, page_index + 1)
	elif mode == Mode.INTRO:
		_show_creator()
	else:
		_start_game()


## ESC: the rest of the intro -> creation; the rest of the montage -> day 1.
func skip() -> void:
	if mode == Mode.INTRO:
		_show_creator()
	elif mode == Mode.MONTAGE:
		_start_game()


func _show_page(m: Mode, index: int) -> void:
	mode = m
	page_index = index
	_offer_panel.visible = false
	_set_page_ui_visible(true)
	var page: Dictionary = pages_for(m)[index]
	var path := ART_DIR + String(page["art"]) + ".png"
	_picture.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_caption.text = fill_page_text(String(page["text"]), _tokens())
	_caption.visible_ratio = 0.0
	if _reveal_tween != null:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_caption, "visible_ratio", 1.0, REVEAL_SECONDS)
	_place_page_player(page)
	_picture_frame.modulate.a = 0.0
	create_tween().tween_property(_picture_frame, "modulate:a", 1.0, FADE_SECONDS)
	var last := index == pages_for(m).size() - 1
	if m == Mode.INTRO:
		_hint.text = HintText.fill(self, "{use} next   {back} skip intro")
	elif last:
		_hint.text = HintText.fill(self, "{use} begin day 1")
	else:
		_hint.text = HintText.fill(self, "{use} next   {back} skip to day 1")
	_refresh_dots()


func _place_page_player(page: Dictionary) -> void:
	var spot = page.get("player", null)
	_page_player.visible = spot is Array
	if not (spot is Array):
		_page_player.stop()
		return
	_page_player.sprite_frames = PlayerLook.build_frames(PLAYER_FRAMES, GameState.player_appearance)
	# Frames are 24x24, centred, feet on row 20: the feet row sits 8 px below the centre.
	_page_player.position = PICTURE_RECT.position + Vector2(float(spot[0]), float(spot[1]) - 1.0 - 8.0)
	_page_player.play(String(spot[2]))


func _refresh_dots() -> void:
	var count := pages_for(mode).size()
	while _dots.get_child_count() < count:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 4)
		_dots.add_child(dot)
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as ColorRect
		dot.visible = i < count
		dot.color = DOT_ACTIVE if i == page_index else DOT_INACTIVE


func _tokens() -> Dictionary:
	var settlement := SettlementDB.get_settlement(GameState.chosen_settlement_id)
	var tokens := PlayerProfile.pronoun_tokens(GameState.player_pronouns)
	tokens["settlement"] = String(settlement.get("name", "the settlement"))
	tokens["name"] = PlayerProfile.name_token(GameState.player_name)
	return tokens


## Pure: fills {token}s in page text (unit-tested in tests/test_player_profile.gd).
static func fill_page_text(text: String, tokens: Dictionary) -> String:
	var out := text
	for key in tokens:
		out = out.replace("{%s}" % key, String(tokens[key]))
	return out


func _set_page_ui_visible(on: bool) -> void:
	_picture_frame.visible = on
	_caption.visible = on
	_hint.visible = on
	_dots.visible = on


## -- Offer (replays) --

func _show_offer() -> void:
	mode = Mode.OFFER
	offer_index = 0
	_set_page_ui_visible(false)
	_hint.visible = true
	_hint.text = HintText.fill(self, "{nav} choose   {use} confirm")
	_offer_panel.visible = true
	_refresh_offer()


func _offer_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		offer_index = 1 - offer_index
		_refresh_offer()
	elif event.is_action_pressed("use_tool") or _is_enter(event):
		if offer_index == 0:
			_show_creator()
		else:
			_show_page(Mode.INTRO, 0)
	elif event.is_action_pressed("ui_cancel"):
		_show_creator()


func _refresh_offer() -> void:
	for i in _offer_rows.size():
		_offer_rows[i].add_theme_color_override("font_color",
			ROW_SELECTED_COLOR if i == offer_index else ROW_COLOR)


## -- Creation --

func _show_creator() -> void:
	mode = Mode.CREATE
	_set_page_ui_visible(false)
	_offer_panel.visible = false
	if creator == null:
		creator = CreatorScript.new()
		creator.name = "CharacterCreator"
		add_child(creator)
		creator.setup(GameState.player_name, GameState.player_pronouns, GameState.player_appearance)
		creator.finished.connect(_on_creator_finished)
	creator.visible = true


func _on_creator_finished(player_name: String, pronouns: String, appearance: Dictionary) -> void:
	GameState.set_profile(player_name, pronouns, appearance)
	creator.visible = false
	_show_page(Mode.MONTAGE, 0)


## -- Day 1 --

func _start_game() -> void:
	if mode == Mode.DONE:
		return
	mode = Mode.DONE
	GameState.mark_opening_seen()
	set_process_unhandled_input(false)
	get_tree().change_scene_to_file(MAIN_SCENE)


## -- Build --

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_picture_frame = Control.new()
	_picture_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture_frame)
	var outer := ColorRect.new()
	outer.color = FRAME_DARK
	outer.position = PICTURE_RECT.position - Vector2(2, 2)
	outer.size = PICTURE_RECT.size + Vector2(4, 4)
	_picture_frame.add_child(outer)
	var inner := ColorRect.new()
	inner.color = FRAME_COLOR
	inner.position = PICTURE_RECT.position - Vector2(1, 1)
	inner.size = PICTURE_RECT.size + Vector2(2, 2)
	_picture_frame.add_child(inner)
	_picture = TextureRect.new()
	_picture.position = PICTURE_RECT.position
	_picture.size = PICTURE_RECT.size
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture_frame.add_child(_picture)
	_page_player = AnimatedSprite2D.new()
	_page_player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_page_player.visible = false
	_picture_frame.add_child(_page_player)
	_caption = Label.new()
	_caption.position = CAPTION_RECT.position
	_caption.size = CAPTION_RECT.size
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", TEXT_COLOR)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_dots = HBoxContainer.new()
	_dots.position = Vector2(140, 172)
	_dots.size = Vector2(40, 4)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 4)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dots)
	_hint = Label.new()
	_hint.position = Vector2(0, 181)
	_hint.size = Vector2(320, 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", HINT_COLOR)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_build_offer()


func _build_offer() -> void:
	_offer_panel = Control.new()
	_offer_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_panel.visible = false
	add_child(_offer_panel)
	var art := TextureRect.new()
	var path := ART_DIR + "clinic.png"
	art.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	art.position = PICTURE_RECT.position
	art.size = PICTURE_RECT.size
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = Color(0.32, 0.28, 0.28, 1.0)
	_offer_panel.add_child(art)
	var title := Label.new()
	title.text = "A NEW LIFE"
	title.position = Vector2(0, 40)
	title.size = Vector2(320, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.add_theme_color_override("font_outline_color", BG_COLOR)
	title.add_theme_constant_override("outline_size", 2)
	_offer_panel.add_child(title)
	var sub := Label.new()
	sub.text = "You know how this story begins."
	sub.position = Vector2(0, 62)
	sub.size = Vector2(320, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", TEXT_COLOR)
	sub.add_theme_color_override("font_outline_color", BG_COLOR)
	sub.add_theme_constant_override("outline_size", 2)
	_offer_panel.add_child(sub)
	for i in 2:
		var row := Label.new()
		row.text = OFFER_SKIP if i == 0 else OFFER_WATCH
		row.position = Vector2(0, 132 + i * 14)
		row.size = Vector2(320, 10)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_offer_panel.add_child(row)
		_offer_rows.append(row)
