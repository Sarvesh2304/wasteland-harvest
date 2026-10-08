extends CanvasLayer
## HUD: day number, in-game clock, energy bar (Phase 2), plus Phase 3's hotbar (always visible,
## bottom-center — the 9 slots number keys 1-9 select) and the 18-slot backpack grid. Phase 4
## adds a second, independently-toggled grid for the farmland storage chest's own Inventory
## instance (see scripts/structures.gd) — walking up to the chest and interacting opens/closes
## it.
##
## Backpack-grid hosting note (2026-07-12 in-game menu session): %InventoryGrid is authored in
## hud.tscn and its slot widgets are still built/painted HERE (bind_inventory below, driven by
## Inventory's signals), but at runtime main.gd hands the node to scripts/menu_screen.gd's
## bind(), which REPARENTS it into the tabbed menu's Inventory tab — the "toggle_inventory"
## key now opens that full menu rather than flipping a bare grid. This script keeps working
## through its captured @onready reference, which survives the reparent; only don't look the
## node up again via hud.get_node("%InventoryGrid") after _ready, since unique-name lookup
## stops resolving once the node leaves this scene's subtree.
##
## Lives on a CanvasLayer so the day/night CanvasModulate in main.tscn never darkens it.
## Listens to the DayManager autoload for time, and to the player's energy_changed signal
## (bound by main.gd) for the energy bar. Art: PixelLab-generated scavenged-metal panel and
## bar frame (art/ui/), with the bar fill drawn as flat palette colors (lamplight gold
## #ffc948 on warm near-black) so the readout stays legible at the 320x192 viewport.
##
## Slot widgets are built procedurally from Inventory.TOTAL_SLOTS rather than hand-authored in
## the .tscn (27 near-identical widgets would be pure boilerplate there) — same "generate from
## data" spirit as scripts/test_map.gd painting tiles from a layout's ASCII grid.
##
## Phase 4 scope note (documented, not an oversight): the chest UI displays and toggles a real
## second Inventory instance, satisfying ROADMAP.md's "opens a second Inventory instance... via
## a small UI" — but this session does not add item-transfer UX (drag/move-in) between the
## player's inventory and the chest's. That's a natural, low-risk follow-up for a later session;
## keeping this session's chest to display/toggle only matches its "keep the UI minimal" scope
## note and avoids inventing new input conventions this codebase doesn't have yet (no mouse
## drag-and-drop exists anywhere else in the UI).
##
## Phase 5 Stage 2 added a small Credits plaque bound to the player's credits_changed signal — the
## same bind-a-signal-to-a-label shape as the energy bar, just without a fill/bar (a plain number
## reads fine for a value this small; a full bar would over-dramatize what's usually a two/three-
## digit balance). It originally lived top-left, mirroring the day/clock plaque's top-right
## positioning; a 2026-07-11 HUD redesign session (playtest feedback: "arrange credits the way
## Stardew shows gold — stacked under the clock, top-right; drop the top-left panel; the HUD
## takes too much space") moved it to stack directly below the clock plaque instead (see
## scenes/hud.tscn's CreditsPlaque node) and shrank the whole corner cluster. That same session
## added the day-progress dial (%DayDial, scripts/day_dial.gd) beside the clock plaque — see
## _on_time_changed below for its wiring.
##
## Stardew-fusion pass (2026-07-11, second HUD session, from a real Stardew screenshot Sarvesh
## shared): the separate ClockPanel plaque + standalone DayDial were replaced by ONE fused
## graphic — DaySign (art/ui/hud_day_sign.png, a salvaged-metal dial welded onto a scrap-wood
## sign), with %DayLabel/%ClockLabel rendering inside the sign's glass window and %DayDial now a
## child Control aligned to the bitmap's dial bezel (its vector fill math/rendering unchanged —
## see scripts/day_dial.gd's hosting note). No weather/season slots on the sign: DayManager has
## neither system yet, and the established convention (see art/ui/README.md's deferred
## season-icon note) is not to fake a system that doesn't exist. Matching Stardew's actual
## layout, the EnergyBar also left the top-right column: it now sits bottom-right, its base
## aligned with the Hotbar's, so the "spend energy using the tool in your hand" readout lives
## next to the hand instead of across the screen. CreditsPlaque keeps hud_plaque.png but now
## draws at an exact half-scale 51x24 with native-8px text (was: native 102x48 with 16px text,
## which screenshot review showed reading BIGGER than the new day sign — backwards from the
## Stardew reference, where gold is the smaller matching sign below; see art/ui/README.md's
## Stardew-fusion section for the integer-scale caveat on that rect).
##
## HUD shrink note (2026-07-11, same session): "shrink ~10%" was applied to panel/plaque
## graphics, gaps, and the energy bar frame — NOT to any font_size or a blanket Control.scale.
## art/ui/README.md's pixel font is only crisp at its native 8px or exact integer multiples
## (16px); a fractional scale on text would reintroduce the exact blur bug that convention exists
## to prevent. Concretely: the clock plaque's WIDTH stayed at 102 (proven to fit "6:00 AM" at the
## existing 24px margins — the widest string this HUD renders) while its HEIGHT dropped ~10%
## (48->43), since the plaque's lower third is baked decorative nameplate art the day/clock text
## never actually used (see art/ui/README.md's provenance note) — free vertical space to reclaim
## without touching anything text-critical. The energy bar frame shrank ~10% on both axes
## (13x64 -> 12x58; no text to protect there). The new Credits plaque is genuinely smaller in
## area than the old top-left one (86x34 vs 102x48) but keeps the same 54px text content width
## the old one already proved fits "999 Cr"-scale balances at font_size 16 — only its height
## shrank, since it now holds one line instead of a taller two-line layout. Inter-element gaps
## tightened 4px -> 3px throughout. Verified visually via tools/screenshot_hud_credits.gd
## (before/after) — text reads exactly as crisp in the "after" shot at every size.

const Inventory := preload("res://scripts/inventory.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const DayDial := preload("res://scripts/day_dial.gd")
## Script-level preload (not the DayManager autoload instance) purely so the pure static rules
## below — crossed_into_night() — can read DAY_START_MINUTES/is_late_night() from a headless
## test with no autoload running. Same pattern as player.gd's own DayManagerScript const.
const DayManagerScript := preload("res://scripts/day_manager.gd")
const Calendar := preload("res://scripts/calendar.gd")
const Weather := preload("res://scripts/weather.gd")

## -- HUD v2 (2026-10-07) --
## "+N item" toasts (bottom-left), the context prompt above the hotbar, and the weather icon
## beside the day sign. Toasts merge repeats of the same item while it's still on screen.
const TOAST_SECONDS := 2.6
const TOAST_WRAP_WIDTH := 190.0
const TOAST_MAX := 4
const TOAST_BG := Color("#281a0b", 0.82)
const TEXT_COLOR := Color("#ffedb1")
const TEXT_OUTLINE := Color("#281a0b")
const WARN_COLOR := Color("#ffb72d")
const WATER_GAUGE_COLOR := Color("#6aa6b8")
## Clear skies show the moon from dusk until dawn.
const NIGHT_ICON_FROM := 19.0 * 60.0
const NIGHT_ICON_UNTIL := 6.0 * 60.0

const HOTBAR_SIZE := Inventory.HOTBAR_SIZE
## 18px slots (2026-10-07 HUD v2): a 16px icon at native size inside a 1px selection frame. The
## old 14px slot squeezed 16px icons down to 12px, dropping pixel rows.
const SLOT_SIZE := 18.0
const SLOT_GAP := 1
const SELECTED_COLOR := Color("#ffc948")  # lamplight gold — GDD.md §9 settlement anchor palette
const EMPTY_BG_COLOR := Color("#281a0b", 0.75)  # warm near-black, per §9

## World-grid cell size in pixels — same 16px tile as player.gd/structures.gd's own CELL_SIZE
## consts; needed here for the chest walk-away distance check below.
const CELL_SIZE := 16.0
## Player-to-chest distance (px) beyond which an open chest/storage UI auto-closes (playtest UX
## gap, 2026-07-10 — Stardew's walking away from an open chest closes it). Interacting range is
## exactly 1 tile (use_tool targets the cell directly ahead, so the player's center sits ~16px
## from the chest's center when interacting, ~23px at the worst diagonal shuffle around it) —
## 3 tiles (48px) is that range plus a comfortable 2 tiles of slack: the player can shift
## freely around the chest while sorting, but deliberately walking a couple of tiles away
## reads as "done with the chest" and closes it.
const CHEST_CLOSE_DISTANCE := 3.0 * CELL_SIZE

## How long the "GETTING SLEEPY..." cue stays up after midnight strikes (2026-08-09 HUD polish,
## from Sarvesh's playtest: the cue used to sit on screen for the WHOLE midnight-to-6-AM window —
## up to 6 real minutes — because hud.gd just mirrored DayManager.is_late_night() every tick).
## 8 seconds is ~6 full pulse cycles at sleepy_pulse_alpha's ~0.8 Hz: unmissable, then gone. It
## fires ONCE per night, on the midnight-crossing edge (see crossed_into_night below) — the
## ongoing consequence of staying up is the energy bar visibly sliding, which is always on screen
## anyway, so the cue's job is to announce the window, not to nag through it.
const SLEEPY_CUE_SECONDS := 8.0

@onready var day_label: Label = %DayLabel
@onready var clock_label: Label = %ClockLabel
@onready var day_dial: Control = %DayDial
@onready var energy_fill: ProgressBar = %EnergyFill
@onready var credits_label: Label = %CreditsLabel
@onready var hotbar_row: HBoxContainer = %Hotbar
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var chest_grid: GridContainer = %ChestGrid
@onready var save_notice: Label = %SaveNotice

var inventory: Inventory = null
## Parallel to inventory.slots — one widget dict per slot: {frame, bg, icon, label}.
var _slot_widgets: Array = []

## Phase 4 chest UI state: whichever Inventory scripts/structures.gd last handed us via
## toggle_chest_ui(), and its own parallel widget array (same shape as _slot_widgets above).
var _chest_inventory: Inventory = null
var _chest_slot_widgets: Array = []
## The interacted storage cell toggle_chest_ui() was last opened at — the walk-away auto-close
## (_process below) measures the player's live distance against this cell's world center.
var _chest_cell := Vector2i.ZERO
## The player node, kept from bind_player() for the walk-away distance check.
var _player: Node = null

## The "GETTING SLEEPY..." cue (2026-08-09 HUD polish). NOT a HUD node any more: it now lives in
## the world as a Label child of the Player scene (scenes/player.tscn's third child, alongside
## Sprite/CollisionShape2D), so it floats above the character's head instead of banner-ing across
## the top of the screen — Sarvesh's playtest read the old top-of-screen version as a system
## message rather than something happening to his character. Parenting it to the Player makes it
## track him for free under any camera pan/clamp, with no screen-projection math.
##
## Authoring notes for that node, kept HERE rather than as .tscn comments — no other scene file
## in this repo carries any, and Godot's editor silently strips them the moment the scene is
## opened (the same comment-eating behaviour that already bit this project's project.godot):
##   - Offsets put its 10px band at local y -28..-18, tucked just above the 24px sprite (drawn at
##     offset (0,-5), so the head tops out at y=-17). A first screenshot pass at -32..-22 left a
##     visibly floating gap.
##   - font_size drops 16 -> native 8 (the theme's other sanctioned crisp size, per
##     art/ui/README.md — NOT a new fractional one) so it reads as a small personal cue.
##   - The authored font_color is what the player actually sees: _show_sleepy_cue() divides the
##     day/night CanvasModulate back out (see tint_compensation).
##
## hud.gd still owns show/hide/pulse — the cue is a clock readout like the day sign and energy
## bar, and keeping one script in charge of "what the clock means on screen" beat scattering a
## second copy of the night rules into player.gd. Resolved in bind_player(); stays null (and
## every touch below no-ops) in the headless/unbound case, which is why the guards are there.
var sleepy_label: Label = null
## One-shot SLEEPY_CUE_SECONDS timer, built in _ready. Started by the midnight edge, stopped
## early if the clock leaves the late-night window first (a bed/pass-out jump back to 6 AM).
var _sleepy_timer: Timer = null


## The "WORLD SAVED" notice's timing (Phase 4 Stage 3): fully visible for HOLD seconds, then
## fades out over FADE seconds. Brief-but-unmissable; total ~2.4s.
const SAVE_NOTICE_HOLD := 1.6
const SAVE_NOTICE_FADE := 0.8

var _save_notice_tween: Tween = null

var _toast_box: VBoxContainer = null
## item_id (or "" for messages) -> {node, label, count, time_left}
var _toasts: Array = []
var _prompt: Label = null
var _target_cursor: Node = null
var _weather_icon: TextureRect = null
## Milestone C: health (beside the energy bar), the radiation meter, the hurt vignette and the
## district banner, all built in code by _build_combat_hud().
var _health_bar: Control = null
var _health_fill: ProgressBar = null
var _rad_bar: Control = null
var _rad_fill: ProgressBar = null
var _vignette: TextureRect = null
var _banner: VBoxContainer = null
var _banner_tween: Tween = null
var _last_hp := -1.0
var _hurt_flash := 0.0
## Set by main.gd: the expedition (for the haul counter) and a callable giving Kael's truck's
## world position in the ruins (for the way-home marker), or null when there's none.
var expedition: Node = null
var truck_position: Callable = Callable()
var _haul_label: Label = null
var _truck_marker: Label = null
var _weather_shown := ""


func _ready() -> void:
	_sleepy_timer = Timer.new()
	_sleepy_timer.one_shot = true
	_sleepy_timer.wait_time = SLEEPY_CUE_SECONDS
	_sleepy_timer.timeout.connect(_hide_sleepy_cue)
	add_child(_sleepy_timer)
	DayManager.time_changed.connect(_on_time_changed)
	# The sleepy cue's ONE-SHOT trigger rides time_advanced, not time_changed: only that signal
	# carries the previous clock reading (so the midnight wrap is detectable as an edge rather
	# than a state), and only that signal is emitted exclusively for lived-through time — a
	# sleep transition's jump back to 6 AM or a save-load's clock restore must never be mistaken
	# for the player staying up. Exactly the reasoning player.gd's night rules already use; see
	# day_manager.gd's time_advanced doc.
	DayManager.time_advanced.connect(_on_time_advanced)
	_on_time_changed(DayManager.day, DayManager.minutes_into_day)
	# Phase 4 Stage 3: transient "WORLD SAVED" notice, driven by the GameState autoload's
	# game_saved signal (fired from the bed's auto-save) — the save system stays UI-agnostic.
	GameState.game_saved.connect(_on_game_saved)
	_build_v2()


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the chest grid (playtest UX gap, 2026-07-10 — the same Stardew "Esc backs out
	# of whatever menu you're in" convention dialogue/store/shipping follow). The backpack grid
	# is no longer toggled here at all: since the 2026-07-12 in-game menu, "toggle_inventory"
	# belongs to scripts/menu_screen.gd, which re-hosts %InventoryGrid as its Inventory tab
	# (see bind()'s note below) and does its own Esc handling. The chest grid stays a passive
	# HUD overlay, opened by re-interacting with the chest, exactly as before.
	if event.is_action_pressed("ui_cancel"):
		chest_grid.visible = false


## Walk-away auto-close for the chest/storage grid (see CHEST_CLOSE_DISTANCE's comment): checked
## continuously while it's open, since nothing freezes the player while a chest is open (it's a
## passive overlay, not a modal surface). Also pulses the late-night sleepy cue's alpha while
## it's up (visibility itself is time-driven — see _on_time_changed).
func _process(delta: float) -> void:
	_tick_toasts(delta)
	_refresh_prompt()
	_tick_combat_hud(delta)
	if chest_grid.visible and _player != null \
			and chest_out_of_range(_player.global_position, _chest_cell):
		chest_grid.visible = false
	if sleepy_label != null and sleepy_label.visible:
		sleepy_label.modulate.a = sleepy_pulse_alpha(Time.get_ticks_msec() / 1000.0)


## Pure pulse curve for the "GETTING SLEEPY..." cue (headless-testable): a slow ~0.8 Hz
## breathing fade between barely-there and fully opaque — animated enough to read as a state,
## not a stuck caption, without strobing the 320x192 screen. Never fully vanishes mid-cycle
## (min alpha 0.1) so the cue can't be missed by glancing up during the trough.
static func sleepy_pulse_alpha(seconds: float) -> float:
	return 0.55 + 0.45 * sin(seconds * TAU * 0.8)


## Pure one-shot edge rule for the sleepy cue (headless-testable): whether a lived-through
## clock interval is the tick that just crossed midnight INTO the late-night window — the single
## moment per night the cue fires. The deliberate counterpart to player.gd's survived_night()
## (the 6 AM edge that ends a stay-awake charge), written in the same shape on purpose.
##
## Why an edge and not is_late_night(new_minutes): that state is true for the whole 6-hour
## window, which is exactly the bug this replaces — mirroring it into a Label's visibility every
## tick is what pinned the banner on screen all night. advance_minutes() only ever moves the
## clock forward, so new < prev IS a genuine midnight crossing (its own doc says so); the
## is_late_night() conjunct then rejects the pathological case of a single tick so large it
## jumped clean over the whole window (>6 game-hours in one emission — impossible from a frame
## delta, reachable only from test tooling), where "you're getting sleepy" would be a lie.
static func crossed_into_night(prev_minutes: float, new_minutes: float) -> bool:
	return new_minutes < prev_minutes and DayManagerScript.is_late_night(new_minutes)


## Pure: the self_modulate that cancels a CanvasModulate tint, so a world-space Control keeps
## the colour it was actually authored with (2026-08-09, and a CONFIRMED problem, not a
## precaution — the first screenshot of the relocated sleepy cue showed it washed down to a
## barely-there dark blue). Moving the cue out of the HUD CanvasLayer and into the world is what
## bought the follow-the-player behaviour; the cost is that main.tscn's DayNight CanvasModulate
## now multiplies it too, and midnight's sky is (0.16, 0.17, 0.30) — a ~5x knock-down on a cue
## whose entire job is to be noticed. Dividing it back out is exact rather than eyeballed, and
## costs one line at show-time instead of a hand-tuned magic colour that would silently rot the
## next time the sky gradient is retuned.
##
## Values above 1.0 are intentional and safe here: the multiply happens in-shader before the
## framebuffer write, so the product lands back at the authored colour rather than clamping.
## max_gain caps how far a near-black sky can push it (a guard for future gradient edits, not a
## case today's keyframes can reach).
static func tint_compensation(sky: Color, max_gain: float = 8.0) -> Color:
	return Color(
		minf(max_gain, 1.0 / maxf(sky.r, 0.001)),
		minf(max_gain, 1.0 / maxf(sky.g, 0.001)),
		minf(max_gain, 1.0 / maxf(sky.b, 0.001)))


## Pure distance rule for the walk-away close (headless-testable, no scene required): whether
## the player's world position is beyond CHEST_CLOSE_DISTANCE of the storage cell's center.
static func chest_out_of_range(player_pos: Vector2, chest_cell: Vector2i,
		max_distance: float = CHEST_CLOSE_DISTANCE) -> bool:
	var chest_center := (Vector2(chest_cell) + Vector2(0.5, 0.5)) * CELL_SIZE
	return player_pos.distance_to(chest_center) > max_distance


## Called by main.gd once the player exists.
func bind_player(player: Node) -> void:
	_player = player
	# The sleepy cue lives on the player now (see sleepy_label's declaration) — get_node_or_null
	# rather than a hard $ path so an older/stripped Player scene degrades to "no cue" instead of
	# crashing the whole HUD bind.
	sleepy_label = player.get_node_or_null("SleepyLabel") as Label
	_hide_sleepy_cue()
	player.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(player.energy, player.max_energy)
	player.credits_changed.connect(_on_credits_changed)
	_on_credits_changed(player.credits)
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(_on_hp_changed)
		player.rads_changed.connect(_on_rads_changed)
		_on_hp_changed(float(player.hp), float(player.effective_max_hp()))
		_on_rads_changed(float(player.rads))


## Called by main.gd once the player's Inventory exists. Builds the slot widgets once, then
## keeps them in sync via Inventory's signals.
func bind_inventory(inv: Inventory) -> void:
	inventory = inv
	_build_slot_widgets()
	inventory.changed.connect(_refresh_all_slots)
	inventory.hotbar_selection_changed.connect(func(_index: int) -> void: _refresh_all_slots())
	_refresh_all_slots()


func _build_slot_widgets() -> void:
	_slot_widgets.clear()
	for i in Inventory.TOTAL_SLOTS:
		var parent: Control = hotbar_row if i < HOTBAR_SIZE else inventory_grid
		_slot_widgets.append(_make_slot_widget(parent))


func _make_slot_widget(parent: Control) -> Dictionary:
	var frame := ColorRect.new()
	frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	frame.color = Color.TRANSPARENT
	parent.add_child(frame)

	var bg := ColorRect.new()
	bg.position = Vector2(1, 1)
	bg.size = Vector2(SLOT_SIZE - 2, SLOT_SIZE - 2)
	bg.color = EMPTY_BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	var icon := TextureRect.new()
	icon.position = Vector2(1, 1)
	icon.size = Vector2(SLOT_SIZE - 2, SLOT_SIZE - 2)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	# -- Placeholder name tag (2026-08-09 HUD polish) --
	# data/items.json's own header comment has always described placeholder_label as "drawn
	# in-engine by hud.gd" for items shipping without icon art — which is every tool in the game
	# today — but no code ever read the field, so the hotbar was a row of anonymous colour
	# swatches and Sarvesh's playtest couldn't tell the hoe from the watering can. Deliberately a
	# SECOND Label rather than reusing the count/durability one below: both have to coexist in
	# the same 14px square, so this one takes the top edge (centered) and leaves the bottom-right
	# corner to the badge that already owned it. Native 8px theme font — art/ui/README.md's pixel
	# font is only crisp at 8 or 16, and 16 would not fit a 3-char tag in 14px.
	#
	# The backing strip first: without it the tag's contrast depends entirely on whichever
	# placeholder_color the item happens to carry, and screenshot review showed that failing on
	# the light swatches (the Watering Can's pale blue) and on the selected slot's gold frame. A
	# fixed band gives every tag the same legible ground, and doubles as a visual separator
	# between the tag row and the badge below it. Top 7px of the slot, inset 1px like `bg` so the
	# selection frame still reads.
	var tag_bg := ColorRect.new()
	tag_bg.position = Vector2(1, 1)
	tag_bg.size = Vector2(SLOT_SIZE - 2, 7)
	tag_bg.color = Color("#281a0b", 0.85)
	tag_bg.visible = false  # only raised alongside a non-empty tag (see _paint_slot)
	tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tag_bg)

	var tag := Label.new()
	tag.position = Vector2(0, 0)
	tag.size = Vector2(SLOT_SIZE, 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.clip_text = true  # a long/hand-edited tag crops instead of bleeding into the next slot
	tag.add_theme_color_override("font_color", Color("#ffedb1"))
	tag.add_theme_color_override("font_outline_color", Color("#281a0b"))
	# Outline 1, not the badge's 2: a 3-character tag nearly fills the 14px slot, and a 2px halo
	# on every glyph made neighbouring slots' tags read as one run-on word in the first
	# screenshot pass. 1px still separates the text from the placeholder_color swatch behind it.
	tag.add_theme_constant_override("outline_size", 1)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tag)

	var label := Label.new()
	# Count/durability text inherits the project theme's pixel font at its native 8px base size
	# (art/ui/ui_theme.tres) — no per-node size override, so it stays crisp at the 4x stretch.
	label.position = Vector2(0, SLOT_SIZE - 8)
	label.size = Vector2(SLOT_SIZE - 1, 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Pre-existing overflow, caught by this session's screenshot review rather than introduced by
	# it: the Scavenger's Bag's durability_max is 999999 (deliberately unbreakable), and an
	# unclipped 6-digit badge spilled left across the whole neighbouring slot. Clipping to the
	# slot is the same containment the tag above uses; nothing legitimate is lost, since every
	# real count/durability in the game is at most 3 digits.
	label.clip_text = true
	label.add_theme_color_override("font_color", Color("#ffedb1"))
	label.add_theme_color_override("font_outline_color", Color("#281a0b"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)

	# Watering-can level (HUD v2): a 2px gauge along the slot's bottom edge.
	var gauge_bg := ColorRect.new()
	gauge_bg.position = Vector2(2, SLOT_SIZE - 4)
	gauge_bg.size = Vector2(SLOT_SIZE - 4, 2)
	gauge_bg.color = Color("#281a0b", 0.9)
	gauge_bg.visible = false
	gauge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(gauge_bg)
	var gauge := ColorRect.new()
	gauge.position = Vector2(2, SLOT_SIZE - 4)
	gauge.size = Vector2(0, 2)
	gauge.color = WATER_GAUGE_COLOR
	gauge.visible = false
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(gauge)

	return {"frame": frame, "bg": bg, "icon": icon, "tag_bg": tag_bg, "tag": tag, "label": label,
		"gauge_bg": gauge_bg, "gauge": gauge}


func _refresh_all_slots() -> void:
	for i in _slot_widgets.size():
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	var selected := index < HOTBAR_SIZE and index == inventory.selected_hotbar_index
	_paint_slot(_slot_widgets[index], inventory.get_slot(index), selected)


## Shared slot-painting logic (Phase 2/3's original single-inventory HUD, generalized in Phase 4
## so the chest UI below can reuse it verbatim for a second, independent Inventory instance).
func _paint_slot(widget: Dictionary, slot: Dictionary, selected: bool) -> void:
	var frame: ColorRect = widget["frame"]
	var bg: ColorRect = widget["bg"]
	var icon: TextureRect = widget["icon"]
	var tag_bg: ColorRect = widget["tag_bg"]
	var tag: Label = widget["tag"]
	var label: Label = widget["label"]

	frame.color = SELECTED_COLOR if selected else Color.TRANSPARENT

	var gauge_bg: ColorRect = widget.get("gauge_bg")
	var gauge: ColorRect = widget.get("gauge")
	if gauge_bg != null:
		gauge_bg.visible = false
		gauge.visible = false

	if slot.is_empty():
		bg.color = EMPTY_BG_COLOR
		icon.texture = null
		tag.text = ""
		tag_bg.visible = false
		label.text = ""
		return

	var item_id := String(slot.get("item_id", ""))
	var item_def := ItemDB.get_item(item_id)
	var icon_path := slot_icon_path(item_id, int(slot.get("tier", 1)), String(item_def.get("icon", "")))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
		bg.color = EMPTY_BG_COLOR
		# Real art speaks for itself — the tag is a stand-in for a missing icon, not a caption.
		tag.text = ""
	else:
		icon.texture = null
		bg.color = Color(String(item_def.get("placeholder_color", "#8c8478")))
		tag.text = String(item_def.get("placeholder_label", ""))
	tag_bg.visible = tag.text != ""

	# Tools never wear out any more (2026-10-07), so the old durability badge is gone; stacks show
	# their count, the watering can shows its water.
	if not slot.has("durability") and int(slot.get("count", 1)) > 1:
		label.text = str(int(slot["count"]))
	else:
		label.text = ""
	if gauge_bg != null and ItemDB.tool_kind(item_id) == "watering_can":
		var capacity := ItemDB.can_capacity(int(slot.get("tier", 1)))
		# A can with no recorded level is full (player.gd's _can_water_left rule).
		var fraction := clampf(float(slot.get("water", capacity)) / float(capacity), 0.0, 1.0)
		gauge_bg.visible = true
		gauge.visible = true
		gauge.size.x = roundf((SLOT_SIZE - 4) * fraction)


## -- Phase 4: farmland storage chest UI --

## Called by main.gd (wired to scripts/structures.gd's chest_toggled signal) whenever the player
## interacts with the chest. Re-interacting while it's already open closes it again (a simple
## toggle, the same shape the backpack grid's old "I"-key toggle had before the 2026-07-12 menu
## adopted it) rather than needing a separate close affordance.
func toggle_chest_ui(inv: Inventory, cell: Vector2i) -> void:
	# The interacted cell anchors the walk-away distance check (see _process above). For a 2x2
	# shed this is whichever footprint cell was targeted — measuring from the side the player
	# actually opened it from is the natural anchor.
	_chest_cell = cell
	if _chest_inventory == inv and chest_grid.visible:
		chest_grid.visible = false
		return
	if _chest_inventory != inv:
		_chest_inventory = inv
		if _chest_slot_widgets.is_empty():
			_build_chest_slot_widgets()
		if not inv.changed.is_connected(_refresh_all_chest_slots):
			inv.changed.connect(_refresh_all_chest_slots)
		_refresh_all_chest_slots()
	chest_grid.visible = true


func _build_chest_slot_widgets() -> void:
	_chest_slot_widgets.clear()
	for i in Inventory.TOTAL_SLOTS:
		_chest_slot_widgets.append(_make_slot_widget(chest_grid))


func _refresh_all_chest_slots() -> void:
	for i in _chest_slot_widgets.size():
		_paint_slot(_chest_slot_widgets[i], _chest_inventory.get_slot(i), false)


## Shows the "WORLD SAVED" notice (16px — the theme's one sanctioned larger size, per
## art/ui/README.md's integer-multiple font convention; colors set in hud.tscn to the HUD's
## established lamplight-gold-on-warm-black) and fades it out. A save landing while the
## previous notice is still fading restarts the sequence from fully visible.
func _on_game_saved() -> void:
	if _save_notice_tween != null:
		_save_notice_tween.kill()
	save_notice.modulate = Color.WHITE
	save_notice.visible = true
	_save_notice_tween = create_tween()
	_save_notice_tween.tween_interval(SAVE_NOTICE_HOLD)
	_save_notice_tween.tween_property(save_notice, "modulate:a", 0.0, SAVE_NOTICE_FADE)
	_save_notice_tween.tween_callback(func() -> void: save_notice.visible = false)


func _on_time_changed(day: int, minutes_into_day: float) -> void:
	# time_changed fires every frame; only touch the labels when the visible text changes.
	var day_text := Calendar.date_text(day)
	if day_label.text != day_text:
		day_label.text = day_text
	var clock := DayManager.format_clock(minutes_into_day)
	if clock_label.text != clock:
		clock_label.text = clock
	# Night rules (2026-07-11, retimed 2026-08-09): the sleepy cue is RAISED by the midnight edge
	# in _on_time_advanced below and drops itself after SLEEPY_CUE_SECONDS. All that's left here
	# is the floor rule that has to hold at every clock reading however it was reached: outside
	# the midnight-to-6-AM window the cue is never up. That covers the teleporting paths
	# time_advanced deliberately never fires for — a bed sleep, a pass-out, a save-load — each of
	# which lands the clock on 6 AM and must clear a mid-countdown cue instantly rather than
	# leave it pulsing over a sunrise.
	if not DayManager.is_late_night(minutes_into_day):
		_hide_sleepy_cue()
	# Day-progress dial (2026-07-11 HUD redesign): re-derived every tick straight from the clock,
	# same as day_label/clock_label above — no separate "day changed" wiring needed since the
	# fraction naturally wraps back to 0 the instant a new day's minutes_into_day resets.
	day_dial.set_fraction(DayDial.day_progress_fraction(
		minutes_into_day, DayManager.MINUTES_PER_DAY, DayManager.DAY_START_MINUTES))
	_refresh_weather_icon()


## Lived-time driver for the one-shot sleepy cue, connected to DayManager.time_advanced in
## _ready() (see the comment there for why that signal). Fires the cue on the midnight edge and
## nowhere else; a second wrap can't arrive until the next night, so no re-trigger guard beyond
## the edge test itself is needed.
func _on_time_advanced(prev_minutes: float, new_minutes: float) -> void:
	if crossed_into_night(prev_minutes, new_minutes):
		_show_sleepy_cue()


func _show_sleepy_cue() -> void:
	if sleepy_label == null:
		return
	# Computed once here rather than per-frame: the cue's whole 8-second life sits inside the
	# flat deep-night stretch of DayManager's gradient (constant from 20:30 to 5:00), so the
	# compensation cannot drift while it's up. See tint_compensation's doc.
	sleepy_label.self_modulate = tint_compensation(DayManager.current_sky_color())
	sleepy_label.modulate.a = 1.0  # _process's pulse takes over from the next frame
	sleepy_label.visible = true
	_sleepy_timer.start(SLEEPY_CUE_SECONDS)


func _hide_sleepy_cue() -> void:
	if _sleepy_timer != null:
		_sleepy_timer.stop()
	if sleepy_label == null:
		return
	sleepy_label.visible = false


func _on_energy_changed(current: float, max_energy: float) -> void:
	energy_fill.max_value = max_energy
	energy_fill.value = current


func _on_credits_changed(current: int) -> void:
	credits_label.text = "%d Cr" % current



## -- HUD v2 (2026-10-07) --

## Pure: which icon a slot shows — an upgraded tool's own art (hoe_t3.png) when it exists.
static func slot_icon_path(item_id: String, tier: int, base_icon: String) -> String:
	if tier > 1 and ItemDB.is_tool_item(item_id):
		var upgraded := "res://art/items/%s_t%d.png" % [item_id, tier]
		if ResourceLoader.exists(upgraded):
			return upgraded
	return base_icon


## Pure: the prompt line for a describe_action() result, e.g. "Space Chop   E Pick up".
static func prompt_text(actions: Dictionary, use_key: String, interact_key: String) -> String:
	var use_verb := String(actions.get("use", ""))
	var interact_verb := String(actions.get("interact", ""))
	if use_verb != "" and use_verb == interact_verb:
		return "%s %s" % [interact_key, interact_verb]
	var parts: Array[String] = []
	if use_verb != "":
		parts.append("%s %s" % [use_key, use_verb])
	if interact_verb != "":
		parts.append("%s %s" % [interact_key, interact_verb])
	return "   ".join(parts)


## Called by main.gd: the prompt mirrors the target cursor's current actions.
func bind_target_cursor(cursor: Node) -> void:
	_target_cursor = cursor


func _build_v2() -> void:
	var root: Control = $Root
	hotbar_row.add_theme_constant_override("separation", SLOT_GAP)
	var hotbar_width := HOTBAR_SIZE * SLOT_SIZE + (HOTBAR_SIZE - 1) * SLOT_GAP
	hotbar_row.offset_left = -hotbar_width / 2.0
	hotbar_row.offset_right = hotbar_width / 2.0
	hotbar_row.offset_top = -SLOT_SIZE - 2.0
	hotbar_row.offset_bottom = -2.0

	_toast_box = VBoxContainer.new()
	_toast_box.name = "Toasts"
	_toast_box.anchor_left = 0.0
	_toast_box.anchor_right = 0.0
	_toast_box.anchor_top = 1.0
	_toast_box.anchor_bottom = 1.0
	_toast_box.offset_left = 3
	_toast_box.offset_right = 110
	_toast_box.offset_top = -SLOT_SIZE - 96.0
	_toast_box.offset_bottom = -SLOT_SIZE - 16.0  # clear of the hotbar and the prompt line
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", 1)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)

	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -120
	_prompt.offset_right = 120
	_prompt.offset_top = -SLOT_SIZE - 13.0
	_prompt.offset_bottom = -SLOT_SIZE - 4.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", TEXT_COLOR)
	_prompt.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	_prompt.add_theme_constant_override("outline_size", 2)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt)

	var sign_node: Control = $Root/DaySign
	_weather_icon = TextureRect.new()
	_weather_icon.name = "WeatherIcon"
	_weather_icon.anchor_left = 1.0
	_weather_icon.anchor_right = 1.0
	_weather_icon.offset_left = sign_node.offset_left - 18.0
	_weather_icon.offset_right = sign_node.offset_left - 2.0
	_weather_icon.offset_top = 13.0
	_weather_icon.offset_bottom = 29.0
	_weather_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_weather_icon)
	_refresh_weather_icon()

	Events.item_gained.connect(_on_item_gained)
	Events.message.connect(_on_message)
	_build_combat_hud()


func _refresh_weather_icon() -> void:
	if _weather_icon == null:
		return
	var kind := String(DayManager.weather_today)
	var m := float(DayManager.minutes_into_day)
	var icon := kind
	if kind == Weather.CLEAR and (m >= NIGHT_ICON_FROM or m < NIGHT_ICON_UNTIL):
		icon = "clear_night"
	if icon == _weather_shown:
		return
	_weather_shown = icon
	var path := "res://art/ui/weather_%s.png" % icon
	_weather_icon.texture = load(path) if ResourceLoader.exists(path) else null
	_weather_icon.tooltip_text = Weather.display_name(kind)


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	var text := ""
	if _target_cursor != null and _target_cursor.visible:
		text = prompt_text(_target_cursor.actions, _key_name("use_tool"), _key_name("interact"))
	if _prompt.text != text:
		_prompt.text = text
		var warn := text.contains("Too tough") or text.contains("Wrong season") or text.contains("Empty")
		_prompt.add_theme_color_override("font_color", WARN_COLOR if warn else TEXT_COLOR)


## The first keyboard key bound to an action, as text ("Space", "E").
func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return ""


func _on_item_gained(item_id: String, count: int) -> void:
	if count <= 0:
		return
	for toast in _toasts:
		if toast["item"] == item_id:
			toast["count"] += count
			toast["time_left"] = TOAST_SECONDS
			(toast["label"] as Label).text = _toast_text(item_id, int(toast["count"]))
			(toast["node"] as Control).modulate.a = 1.0
			return
	_add_toast(item_id, count, _toast_text(item_id, count))


func _on_message(text: String) -> void:
	_add_toast("", 0, text)


static func _toast_text(item_id: String, count: int) -> String:
	return "+%d %s" % [count, ItemDB.display_name(item_id)]


func _add_toast(item_id: String, count: int, text: String) -> void:
	if _toast_box == null:
		return
	while _toasts.size() >= TOAST_MAX:
		var oldest: Dictionary = _toasts.pop_front()
		(oldest["node"] as Control).queue_free()
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = TOAST_BG
	style.content_margin_left = 2
	style.content_margin_right = 4
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if item_id != "":
		var icon_path := String(ItemDB.get_item(item_id).get("icon", ""))
		if ResourceLoader.exists(icon_path):
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2(16, 16)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	# Long messages (Kael's lines, warnings) wrap instead of running under the HP/energy bars,
	# and stay up a little longer.
	var seconds := TOAST_SECONDS
	var font := label.get_theme_font("font")
	if font != null and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size("font_size")).x > TOAST_WRAP_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = TOAST_WRAP_WIDTH
		seconds *= 1.6
	_toast_box.add_child(panel)
	_toasts.append({"item": item_id, "count": count, "time_left": seconds,
		"node": panel, "label": label})


func _tick_toasts(delta: float) -> void:
	for toast in _toasts.duplicate():
		toast["time_left"] = float(toast["time_left"]) - delta
		var node: Control = toast["node"]
		if toast["time_left"] <= 0.0:
			_toasts.erase(toast)
			node.queue_free()
		elif toast["time_left"] < 0.5:
			node.modulate.a = float(toast["time_left"]) / 0.5


## -- Milestone C: health, radiation, hurt vignette, district banner --

const HP_FILL := Color("#c43020")
const RAD_FILL := Color("#86e83e")


func _build_combat_hud() -> void:
	var root: Control = $Root
	var energy_bar: Control = $Root/EnergyBar
	_health_bar = _clone_bar(energy_bar, "HealthBar", HP_FILL, -14.0)
	_health_fill = _health_bar.get_node("Fill")
	_add_bar_icon(_health_bar, "res://art/ui/hp_icon.png")
	root.add_child(_health_bar)
	_rad_bar = _clone_bar(energy_bar, "RadBar", RAD_FILL, -28.0)
	_rad_fill = _rad_bar.get_node("Fill")
	_rad_fill.max_value = 200.0
	_add_bar_icon(_rad_bar, "res://art/ui/rad_icon.png")
	root.add_child(_rad_bar)
	_health_bar.visible = false
	_rad_bar.visible = false
	# A soft red edge that pulses when HP runs low and flashes on a hit.
	_vignette = TextureRect.new()
	_vignette.name = "HurtVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.6, 0.02, 0.0, 0.75))
	grad.add_point(0.55, Color(0.6, 0.0, 0.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 64
	tex.height = 40
	_vignette.texture = tex
	_vignette.modulate.a = 0.0
	root.add_child(_vignette)
	root.move_child(_vignette, 0)
	# District banner: top centre, fades in and out on arrival.
	_banner = VBoxContainer.new()
	_banner.name = "Banner"
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -110
	_banner.offset_right = 110
	_banner.offset_top = 34
	_banner.offset_bottom = 60
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_constant_override("separation", 0)
	for i in 2:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", TEXT_COLOR if i == 0 else WARN_COLOR)
		label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
		label.add_theme_constant_override("outline_size", 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_child(label)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	# What a death would cost: the haul so far, under the bars.
	_haul_label = Label.new()
	_haul_label.name = "Haul"
	_haul_label.anchor_left = 1.0
	_haul_label.anchor_right = 1.0
	_haul_label.anchor_top = 1.0
	_haul_label.anchor_bottom = 1.0
	_haul_label.offset_left = -96
	_haul_label.offset_right = -34
	_haul_label.offset_top = -12
	_haul_label.offset_bottom = -2
	_haul_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_haul_label.add_theme_color_override("font_color", TEXT_COLOR)
	_haul_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	_haul_label.add_theme_constant_override("outline_size", 2)
	_haul_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haul_label.visible = false
	root.add_child(_haul_label)
	# Points the way home when Kael's truck is off screen.
	_truck_marker = Label.new()
	_truck_marker.name = "TruckMarker"
	_truck_marker.add_theme_color_override("font_color", Color("#ffc948"))
	_truck_marker.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	_truck_marker.add_theme_constant_override("outline_size", 2)
	_truck_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_truck_marker.visible = false
	root.add_child(_truck_marker)


## A copy of the energy bar (frame + fill) `dx` px to its left, filled with `color`.
func _clone_bar(source: Control, bar_name: String, color: Color, dx: float) -> Control:
	var bar: Control = source.duplicate()
	bar.name = bar_name
	bar.offset_left += dx
	bar.offset_right += dx
	for child in bar.get_children():
		if child is ProgressBar:
			child.unique_name_in_owner = false
			child.name = "Fill"
			var style = (child as ProgressBar).get_theme_stylebox("fill")
			if style is StyleBoxFlat:
				var fill: StyleBoxFlat = (style as StyleBoxFlat).duplicate()
				fill.bg_color = color
				(child as ProgressBar).add_theme_stylebox_override("fill", fill)
	return bar


func _add_bar_icon(bar: Control, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.position = Vector2(1, -10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(icon)


func _on_hp_changed(current: float, max_hp: float) -> void:
	if _health_fill == null:
		return
	_health_fill.max_value = maxf(max_hp, 1.0)
	_health_fill.value = current
	if _last_hp >= 0.0 and current < _last_hp - 0.5:
		_hurt_flash = 1.0
	_last_hp = current


func _on_rads_changed(rads: float) -> void:
	if _rad_fill == null:
		return
	_rad_fill.value = rads
	_rad_bar.visible = rads > 0.5


## Called by main.gd on arriving in a ruins district.
func show_banner(title: String, subtitle: String) -> void:
	if _banner == null:
		return
	(_banner.get_child(0) as Label).text = title
	(_banner.get_child(1) as Label).text = subtitle
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = _banner.create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.5).set_delay(0.3)
	_banner_tween.tween_interval(2.4)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	if _banner != null:
		_banner.modulate.a = 0.0


func _tick_combat_hud(delta: float) -> void:
	if _player == null or _health_bar == null or not _player.has_method("effective_max_hp"):
		return
	var max_hp := float(_player.effective_max_hp())
	var hp := float(_player.hp)
	_health_bar.visible = String(_player.current_zone_id) == "ruins" or hp < max_hp - 0.5
	_hurt_flash = maxf(_hurt_flash - delta * 2.5, 0.0)
	var low := 0.0
	if hp < max_hp * 0.3 and not bool(_player.dead):
		low = 0.35 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
	_vignette.modulate.a = clampf(maxf(low, _hurt_flash * 0.8), 0.0, 1.0)
	_tick_expedition_widgets()


func _tick_expedition_widgets() -> void:
	var in_ruins := String(_player.current_zone_id) == "ruins" and expedition != null and bool(expedition.active)
	_haul_label.visible = in_ruins
	if in_ruins:
		var n := 0
		for item_id in expedition.ledger:
			n += int(expedition.ledger[item_id])
		_haul_label.text = "Haul %d" % n
	_truck_marker.visible = false
	if not in_ruins or not truck_position.is_valid():
		return
	var world_pos = truck_position.call()
	if not (world_pos is Vector2):
		return
	var screen: Vector2 = get_viewport().get_canvas_transform() * (world_pos as Vector2)
	var view := Vector2(320, 192)
	var margin := 10.0
	if screen.x >= 0.0 and screen.y >= 0.0 and screen.x <= view.x and screen.y <= view.y:
		return
	var center := view / 2.0
	var dir := (screen - center)
	if dir.length() < 0.01:
		return
	var scale := minf((center.x - margin) / maxf(absf(dir.x), 0.01), (center.y - margin) / maxf(absf(dir.y), 0.01))
	var at := center + dir * scale
	var arrow := "<" if absf(dir.x) >= absf(dir.y) and dir.x < 0.0 else (">" if absf(dir.x) >= absf(dir.y) else ("^" if dir.y < 0.0 else "v"))
	_truck_marker.text = arrow + " Truck" if arrow == "<" else ("Truck " + arrow if arrow == ">" else "Truck " + arrow)
	_truck_marker.reset_size()
	var size := _truck_marker.get_combined_minimum_size()
	# Keep it in the play area: below the date sign, above the hotbar, clear of the HP/energy bars.
	_truck_marker.position = (at - size / 2.0).clamp(Vector2(2, 14), Vector2(view.x - size.x - 34.0, view.y - size.y - 34.0))
	_truck_marker.visible = true
