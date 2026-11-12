extends CanvasLayer
## Phase 5 Stage 1 dialogue box (ROADMAP.md "interact near an NPC to open a dialogue box,
## character-by-character text, basic branching, dialogue stored in JSON for easy editing").
## Tree traversal itself is scripts/dialogue_db.gd's pure static functions; this node is just
## the stateful presentation shell around them — same farm.gd/farm_grid.gd split.
##
## Opened via player.gd's npc_dialogue_requested signal (main.gd wires it to open_dialogue()
## here, mirroring structures.gd's chest_toggled -> hud.toggle_chest_ui() pattern) rather than a
## direct method call from player.gd, so player.gd stays instance-testable without a real
## DialogueUI scene existing (tests/test_player.gd).
##
## Keyboard-only, reusing existing input actions — no new project.godot entries needed:
##   - "use_tool" (Space/E) advances: on a node whose text hasn't finished revealing, the first
##     press instantly reveals the rest (Stardew's "skip the typewriter" convention rather than
##     forcing players to wait out every line); once revealed, the next press moves on to
##     whichever node is next (following the currently-highlighted choice, if the node has any),
##     and pressing it on a terminal node (no "next", no choices) closes the box.
##   - "move_up"/"move_down" (W/S + arrows), only meaningful once the current node's text is
##     fully revealed AND it has choices, move the highlighted option — the same cycle-then-
##     confirm shape settlement_select.gd's picker already uses, reused here rather than
##     inventing a new "pick a response" binding.
## While open, player.gd's _physics_process freezes entirely (its _in_dialogue() gate) and the
## talking NPC freezes too (npc.gd's set_talking) — close() unfreezes both unconditionally, so a
## conversation can never leave the player or the NPC stuck.
##
## Phase 5 Stage 2: a choice's "next" can also be the OPEN_STORE_SENTINEL below (see
## data/dialogue.json's class doc) — landing on it closes this box and emits store_requested
## instead of advancing to another node, so Marta's "Let's see what you've got" choice opens
## scripts/store_ui.gd rather than just printing more text.
##
## Phase 7 Stage 3 (affinity) adds two responsibilities here, both deliberately in this
## presentation shell rather than in the pure dialogue_db.gd (same domain-split reasoning as the
## sentinels above):
##   1. THE TALK TICK. A real conversation opening awards a once-per-day affinity point
##      (affinity.try_award_talk, which owns both the named-NPC gate and the daily cap). "Real"
##      means the player walked up and talked: open_dialogue() below. The scripted entry point
##      open_dialogue_at() — the Day-28 food-shortage beat and main.gd's "not_yet" ranch-store
##      branch — never awards, since neither is the player choosing to strike up a conversation.
##      Both still funnel through the same _open_dialogue_at(); the two public entry points
##      differ only in the `award_affinity` flag they pass, so there is exactly one open path.
##   2. CHOICE FILTERING. Every rendered/traversed choice list goes through _available_choices()
##      (DialogueDB.choice_available per choice), so a choice carrying "min_affinity" is hidden
##      below that value. Filtering happens in ONE place and every consumer — the up/down
##      selection, the reveal-gated visibility, the hint text and _advance()'s own traversal —
##      reads that same filtered list, so the highlighted index can never address a hidden option.

const DialogueDB := preload("res://scripts/dialogue_db.gd")
const GiftDB := preload("res://scripts/gift_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const Calendar := preload("res://scripts/calendar.gd")
const UIText := preload("res://scripts/ui_text.gd")

## Reveal rate for the character-by-character typewriter effect.
const CHARS_PER_SECOND := 28.0
## Comfortably longer than any authored line takes to reveal at CHARS_PER_SECOND — "instantly
## reveal the rest" just fast-forwards _elapsed past this, no special-cased skip flag needed.
const INSTANT_REVEAL_ELAPSED := 999.0

## Recognized only here (the presentation shell), not in scripts/dialogue_db.gd, which stays a
## domain-agnostic pure traversal module with no concept of "a store."
const OPEN_STORE_SENTINEL := "OPEN_STORE"
const OPEN_RANCH_STORE_SENTINEL := "OPEN_RANCH_STORE"

## Phase 8 Stage 3 (settler arrivals): the same runtime-sentinel pattern as OPEN_STORE_SENTINEL
## above, recognized only here — a visiting settler's greeting tree (scripts/settlers.gd's
## _greeting_dialogue, registered via dialogue_db.gd's register_runtime) ends its 2-choice branch
## on one of these instead of another node id.
const SETTLER_ACCEPT_SENTINEL := "SETTLER_ACCEPT"
const SETTLER_REJECT_SENTINEL := "SETTLER_REJECT"

## Milestone B (2026-10-08): Doc Ama's clinic service (after the clinic Town Works project), and
## the gift hand-over choice this box synthesizes itself.
const CLINIC_HEAL_SENTINEL := "CLINIC_HEAL"
const OPEN_CLINIC_STORE_SENTINEL := "OPEN_CLINIC_STORE"
## Milestone D: Tully's caravan stock, and the main story's decision (docs/LIVING_SETTLEMENT.md).
const OPEN_CARAVAN_SENTINEL := "OPEN_CARAVAN"
const STORY_HOME_SENTINEL := "STORY_HOME"
const STORY_SHARED_SENTINEL := "STORY_SHARED"
const GIFT_SENTINEL := "_GIVE_GIFT"

## Fallback reactions for an NPC without authored gift lines of that kind.
const GENERIC_GIFT_LINES := {
	"loved": "Oh! This is wonderful. Thank you!",
	"liked": "Thank you. This is lovely.",
	"neutral": "Thanks. That's kind of you.",
	"disliked": "Oh. Um. Thanks, I suppose.",
	"hated": "...Why would you give me this?",
	"birthday": "You remembered my birthday? Thank you.",
	"birthday_loved": "On my birthday, too? You're a treasure.",
}

const CHOICE_COLOR := Color("#7b5025")            # worn wood (dark) — unselected choice
const CHOICE_SELECTED_COLOR := Color("#c5520f")   # rust red — reads as "this one's highlighted"

## Phase 5 Stage 2: fired when a conversation's choice leads to OPEN_STORE_SENTINEL — main.gd
## wires this to scripts/store_ui.gd's open_store(), the same one-level-deeper handoff shape as
## player.gd's own npc_dialogue_requested -> main.gd -> DialogueUI.open_dialogue().
signal store_requested(npc: Node)
signal ranch_store_requested(npc: Node)

## Phase 8 Stage 3: fired when a conversation's choice leads to SETTLER_ACCEPT_SENTINEL/
## SETTLER_REJECT_SENTINEL — main.gd wires this to scripts/settlers.gd's resolve_visitor(),
## the same one-level-deeper handoff shape as store_requested above.
signal settler_decision_requested(npc: Node, accepted: bool)
## Milestone B: Doc Ama's clinic choices (main.gd heals the player / opens the clinic shelf).
signal clinic_heal_requested(npc: Node)
signal clinic_store_requested(npc: Node)
signal caravan_requested(npc: Node)
## The main story's decision was made ("home" or "shared"); main.gd's story node takes it from there.
signal story_choice(npc: Node, choice: String)
## A gift was handed over and reacted to (main.gd floats the reaction).
signal gift_reacted(npc: Node, item_id: String, reaction: String)
## A gift couldn't be given ("today"/"week") while the player held something giftable.
signal gift_refused(npc: Node, reason: String)

@onready var box: Control = %Box
@onready var name_label: Label = %NameLabel
@onready var body_label: Label = %BodyLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var hint_label: Label = %HintLabel

## True while a conversation is open — player.gd's _in_dialogue() reads this directly (same
## shape as builder.gd's `active`).
var active := false
## Phase 6: the shared modal mutual-exclusion registry (scripts/modal_gate.gd), assigned by
## main.gd — open_dialogue() refuses while any other modal surface (build mode, store, shipping
## UI) is open. Structurally this was already unreachable (player.use_tool(), the only trigger,
## can't fire while build mode or another freeze-surface is active), but the gate makes the
## invariant explicit rather than incidental to player.gd's dispatch details.
var modal_gate: RefCounted = null
## Phase 7 Stage 3: the settlement-wide relationship track (scripts/affinity.gd), assigned by
## main.gd at boot like modal_gate above. null when unbound (a bare DialogueUI in a test or tool),
## in which case the talk tick is skipped and choice filtering runs against a value of 0 — i.e.
## exactly today's behaviour, since no authored choice carries "min_affinity" yet.
var affinity: Node = null
var npc: Node = null
## Milestone B (assigned by main.gd; all optional, so a bare DialogueUI still works v1-style):
## the player (held item for gifts), a Callable returning the world context for daily lines
## ({season, weather, time, weekday, flags}), and a Callable(npc_id) -> {"text"} that hands in a
## finished notice-board request and returns the requester's thanks ({} if nothing to hand in).
var player: Node = null
var context_provider: Callable = Callable()
var delivery_hook: Callable = Callable()
## Milestone D: whether a gift to this NPC today is the player's Winter Gathering gift
## (festivals.gd is_circle_gift); it counts five times, like a birthday.
var circle_check: Callable = Callable()
## Milestone D: the main story (story.gd conversation_for). Called with an NPC id; returns "" for
## an ordinary chat, a node id to open instead (Harlan's story_* nodes), or {"text": ...} for a
## one-off line. story_opened fires once such a conversation has actually opened.
var story_hook: Callable = Callable()
signal story_opened(npc_id: String, what: Variant)

## Nodes this conversation made up on the spot (today's line, the gift reaction), looked up
## before the authored ones.
var _dynamic: Dictionary = {}
var _gift_item := ""
var _after_line := ""

var _node_id := ""
var _full_text := ""
var _elapsed := 0.0
var _choice_index := 0
var _choice_labels: Array[Label] = []


func _ready() -> void:
	box.visible = false
	for child in choices_box.get_children():
		_choice_labels.append(child as Label)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_refresh_body()


## Opens a dialogue for `target_npc` at its data's start node. Called by main.gd, wired to
## player.gd's npc_dialogue_requested signal. A no-op if the npc has no dialogue.json entry
## (defensive — every roster NPC has one, see tests/test_dialogue_db.gd).
func open_dialogue(target_npc: Node) -> bool:
	var id := String(target_npc.npc_id)
	# The first conversation ever is the intro tree; so is every conversation with an NPC that has
	# no daily lines (settlers), or when no affinity track is bound (bare tools/tests).
	var met := affinity != null and int(affinity.last_talked_day(id)) != -1
	var story: Variant = story_hook.call(id) if story_hook.is_valid() and met else ""
	if story is Dictionary or String(story) != "":
		var opened := false
		if story is Dictionary:
			_dynamic = {"_story": {"text": String((story as Dictionary).get("text", "..."))}}
			_gift_item = ""
			opened = _open_dialogue_at(target_npc, "_story", true, false)
		else:
			opened = _open_dialogue_at(target_npc, String(story), true)
		if opened:
			story_opened.emit(id, story)
		return opened
	if not met or not DialogueDB.has_daily_lines(id):
		return _open_dialogue_at(target_npc, DialogueDB.start_node_id(id), true)
	return _open_daily(target_npc)


## A later conversation (docs/SOCIAL_AND_QUESTS.md §3): a handed-in request's thanks, else today's
## line (or a repeat on a second chat), then a gift offer if the player holds something giftable,
## then the NPC's service node (if its condition holds).
func _open_daily(target_npc: Node) -> bool:
	var id := String(target_npc.npc_id)
	if active or (modal_gate != null and modal_gate.is_any_open_except(self)):
		return false
	var day: int = DayManager.day
	var first_today := int(affinity.last_talked_day(id)) != day
	var ctx := conversation_context(id)
	var text := ""
	var delivered: Dictionary = delivery_hook.call(id) if delivery_hook.is_valid() else {}
	if not delivered.is_empty():
		text = String(delivered.get("text", ""))
	elif first_today:
		var line := DialogueDB.pick_line(DialogueDB.daily_lines(id), ctx, _seen_lines(id),
			DialogueDB.daily_seed(id, day))
		text = String(line.get("text", ""))
		if bool(line.get("once", false)):
			affinity.mark_line_seen(String(line.get("id", "")))
	else:
		text = DialogueDB.pick_text(DialogueDB.repeat_lines(id), DialogueDB.daily_seed(id, day, "repeat"))
	if text == "":
		text = String(DialogueDB.dialogue_node(id, DialogueDB.start_node_id(id)).get("text", "..."))
	text = DialogueDB.fill(text, {"season": Calendar.SEASON_NAMES.get(DayManager.season(), "")})
	_after_line = ""
	var service := DialogueDB.service_node_id(id)
	if service != "" and DialogueDB.when_matches(DialogueDB.service_when(id), ctx):
		_after_line = service
	_gift_item = _offerable_gift(target_npc, bool(ctx["flags"].has("birthday")) or _is_circle_gift(id))
	if _gift_item != "":
		_dynamic = {"_line": {"text": text, "choices": [
			{"text": "Give the %s" % ItemDB.display_name(_gift_item), "next": GIFT_SENTINEL},
			{"text": "Not today", "next": _after_line}]}}
	else:
		_dynamic = {"_line": {"text": text, "next": _after_line}}
	return _open_dialogue_at(target_npc, "_line", true, false)


## The context daily lines are matched against: the world (main.gd's context_provider) plus this
## NPC's tier and whether today is their birthday.
func conversation_context(npc_id: String) -> Dictionary:
	var ctx: Dictionary = {}
	if context_provider.is_valid():
		ctx = (context_provider.call() as Dictionary).duplicate(true)
	if not ctx.has("season"):
		ctx["season"] = DayManager.season()
	if not ctx.has("weather"):
		ctx["weather"] = DayManager.weather_today
	if not ctx.has("time"):
		ctx["time"] = DialogueDB.time_band(DayManager.minutes_into_day)
	if not ctx.has("weekday"):
		ctx["weekday"] = Calendar.weekday(DayManager.day)
	var flags: Dictionary = ctx.get("flags", {})
	if is_birthday(npc_id, DayManager.day):
		flags["birthday"] = true
	ctx["flags"] = flags
	ctx["tier"] = String(affinity.tier_for(npc_id)) if affinity != null else "stranger"
	return ctx


func _is_circle_gift(npc_id: String) -> bool:
	return circle_check.is_valid() and bool(circle_check.call(npc_id))


static func is_birthday(npc_id: String, day: int) -> bool:
	var b := DialogueDB.birthday(npc_id)
	return not b.is_empty() and Calendar.season(day) == String(b["season"]) \
		and Calendar.day_of_season(day) == int(b["day"])


## The once-only lines of `npc_id` already seen (affinity.gd keeps that memory; pick_line only
## needs a has() lookup). Takes the id: this runs before the conversation sets `npc`.
func _seen_lines(npc_id: String) -> Dictionary:
	var out := {}
	if affinity != null:
		for line in DialogueDB.daily_lines(npc_id):
			var line_id := String((line as Dictionary).get("id", ""))
			if line_id != "" and affinity.has_seen_line(line_id):
				out[line_id] = true
	return out


## The held item if it can be given to `target_npc` right now, else "". Holding something giftable
## when today's (or this week's) gift is already used tells the player why there's no offer.
func _offerable_gift(target_npc: Node, birthday: bool) -> String:
	if player == null or affinity == null:
		return ""
	var item := String(player.inventory.get_selected_slot().get("item_id", ""))
	if item == "" or not GiftDB.is_giftable(item):
		return ""
	var refusal := String(affinity.gift_refusal(String(target_npc.npc_id), item, DayManager.day, birthday))
	if refusal == "today" or refusal == "week":
		gift_refused.emit(target_npc, refusal)
	return item if refusal == "" else ""


## Opens an authored alternate entry point for a scripted beat while retaining the same NPC,
## presentation, input handling, and normal interaction path. The beat caller owns its one-time
## save flag; this method only reports whether the modal actually opened. Never awards affinity
## (see class doc item 1) — a beat the game starts at the player is not the player choosing to
## talk, and the Day-28 shortage in particular fires unprompted at day start.
func open_dialogue_at(target_npc: Node, start_node_id: String) -> bool:
	return _open_dialogue_at(target_npc, start_node_id, false)


## The one shared open path. `award_affinity` distinguishes a real player-initiated conversation
## from a scripted beat; the award itself only lands if the box ACTUALLY opened (an already-open
## box, a missing dialogue entry, or another modal holding the gate all return early before it),
## so a refused open can never hand out a point.
func _open_dialogue_at(target_npc: Node, start_node_id: String, award_affinity: bool,
		clear_dynamic: bool = true) -> bool:
	if active or not DialogueDB.has_dialogue(String(target_npc.npc_id)):
		return false
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return false
	if clear_dynamic:
		_dynamic = {}
		_gift_item = ""
	npc = target_npc
	npc.set_talking(true)
	active = true
	box.visible = true
	name_label.text = DialogueDB.display_name(String(npc.npc_id))
	if award_affinity and affinity != null:
		# affinity.gd owns both gates (named NPCs only, once per day) — this call site stays
		# deliberately unconditional so the rules live in one place.
		affinity.try_award_talk(String(npc.npc_id), DayManager.day)
	_goto_node(start_node_id)
	return true


func close() -> void:
	active = false
	box.visible = false
	if npc != null:
		npc.set_talking(false)
	npc = null


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Esc backs out of the conversation (playtest UX gap, 2026-07-10 — Stardew's "Esc closes
	# whatever menu you're in" convention). Godot's built-in "ui_cancel" action (Escape) is used
	# as-is; project.godot doesn't override it. Additive: the existing close paths (advancing
	# past a terminal node) are untouched, and close() already unfreezes player and NPC
	# unconditionally, so backing out mid-conversation can never leave either stuck.
	if event.is_action_pressed("ui_cancel"):
		close()
		return
	var choices := _available_choices()
	if not choices.is_empty() and _is_fully_revealed():
		if event.is_action_pressed("move_up"):
			_choice_index = wrapi(_choice_index - 1, 0, choices.size())
			_refresh_choices()
			return
		elif event.is_action_pressed("move_down"):
			_choice_index = wrapi(_choice_index + 1, 0, choices.size())
			_refresh_choices()
			return
	if event.is_action_pressed("use_tool"):
		_advance()


func _advance() -> void:
	if not _is_fully_revealed():
		_elapsed = INSTANT_REVEAL_ELAPSED
		_refresh_body()
		return
	# advance_from() is fed the FILTERED node (see _filtered_node) so the highlighted index means
	# the same thing here as it does on screen. A branch whose every choice is gated out therefore
	# falls through to the node's own "next" (absent on a branch node -> "" -> close), rather than
	# silently following a hidden option.
	var next_id := DialogueDB.advance_from(_filtered_node(), _choice_index)
	if next_id == OPEN_STORE_SENTINEL:
		_open_store()
	elif next_id == OPEN_RANCH_STORE_SENTINEL:
		_open_ranch_store()
	elif next_id == SETTLER_ACCEPT_SENTINEL:
		_resolve_settler_decision(true)
	elif next_id == SETTLER_REJECT_SENTINEL:
		_resolve_settler_decision(false)
	elif next_id == GIFT_SENTINEL:
		_give_gift()
	elif next_id == CLINIC_HEAL_SENTINEL:
		var target_npc := npc
		close()
		clinic_heal_requested.emit(target_npc)
	elif next_id == OPEN_CLINIC_STORE_SENTINEL:
		var target_npc := npc
		close()
		clinic_store_requested.emit(target_npc)
	elif next_id == OPEN_CARAVAN_SENTINEL:
		var target_npc := npc
		close()
		caravan_requested.emit(target_npc)
	elif next_id == STORY_HOME_SENTINEL or next_id == STORY_SHARED_SENTINEL:
		var target_npc := npc
		close()
		story_choice.emit(target_npc, "home" if next_id == STORY_HOME_SENTINEL else "shared")
	elif next_id == "":
		close()
	else:
		_goto_node(next_id)


## Closes the conversation and hands off to scripts/store_ui.gd (see class doc / the sentinel's
## comment above). Captures `npc` before close() clears the field.
func _open_store() -> void:
	var target_npc := npc
	close()
	store_requested.emit(target_npc)


func _open_ranch_store() -> void:
	var target_npc := npc
	close()
	ranch_store_requested.emit(target_npc)


## Closes the conversation and hands off to scripts/settlers.gd's resolve_visitor() (see class
## doc / the sentinels' comment above). Captures `npc` before close() clears the field, same
## shape as _open_store().
func _resolve_settler_decision(accepted: bool) -> void:
	var target_npc := npc
	close()
	settler_decision_requested.emit(target_npc, accepted)


func _goto_node(node_id: String) -> void:
	_node_id = node_id
	_elapsed = 0.0
	_choice_index = 0
	# Every node's text goes through fill() so authored lines can use {name} (Milestone E).
	_full_text = DialogueDB.fill(String(_current_node().get("text", "")), {})
	_refresh_body()
	_refresh_choices()
	_layout_box()


## The box grows upward to fit a long line and its choices (2026-10-08: a two-line daily line plus
## a gift offer used to put the choices over the text). Base 68 px tall and 4 px off the bottom
## edge; the body starts 18 px down, the choices sit just under it, the hint keeps the bottom.
const BOX_MIN_HEIGHT := 68.0
const BODY_TOP := 18.0
const BODY_WIDTH := 300.0
const CHOICE_ROW := 9.0
const HINT_SPACE := 12.0


func _layout_box() -> void:
	var body_h := UIText.wrapped_height(body_label, _full_text, BODY_WIDTH)
	var n := _available_choices().size()
	var needed := BODY_TOP + body_h + (3.0 + float(n) * CHOICE_ROW if n > 0 else 0.0) + HINT_SPACE
	box.offset_top = -4.0 - maxf(BOX_MIN_HEIGHT, ceilf(needed))
	choices_box.offset_top = BODY_TOP + body_h + 3.0


func _current_node() -> Dictionary:
	if _dynamic.has(_node_id):
		return _dynamic[_node_id]
	return DialogueDB.dialogue_node(String(npc.npc_id), _node_id)


## Hands the held item over: affinity.gd scores it, the NPC reacts (their own line for that
## reaction, a birthday line on their birthday), then the conversation carries on to the service.
func _give_gift() -> void:
	var id := String(npc.npc_id)
	var birthday := is_birthday(id, DayManager.day)
	if _gift_item == "" or player == null or int(player.inventory.remove_item(_gift_item, 1)) < 1:
		if _after_line != "":
			_goto_node(_after_line)
		else:
			close()
		return
	var result: Dictionary = affinity.give_gift(id, _gift_item, DayManager.day, birthday or _is_circle_gift(id))
	var reaction := String(result["reaction"])
	var kind := reaction
	if birthday:
		kind = "birthday_loved" if reaction == "loved" else "birthday"
	var text := DialogueDB.pick_text(DialogueDB.gift_lines(id, kind),
		DialogueDB.daily_seed(id, DayManager.day, "gift"))
	if text == "":
		text = String(GENERIC_GIFT_LINES.get(kind, GENERIC_GIFT_LINES["neutral"]))
	var item := _gift_item
	_gift_item = ""
	_dynamic["_gift_reply"] = {"text": DialogueDB.fill(text, {"item": ItemDB.display_name(item)}),
		"next": _after_line}
	gift_reacted.emit(npc, item, reaction)
	_goto_node("_gift_reply")


## -- Phase 7 Stage 3: affinity-gated choices (see class doc item 2) --

## The player's current relationship value with the NPC being spoken to; 0 when this box has no
## affinity node bound or no NPC (the same value a never-met NPC has, so an unbound UI renders
## exactly what a first meeting would).
func _affinity_value() -> int:
	if affinity == null or npc == null:
		return 0
	return int(affinity.value_for(String(npc.npc_id)))


## The current node's choices with every affinity-gated one removed. The single source of truth
## for "which options exist right now" — selection, rendering, visibility and traversal all read
## this, never DialogueDB.node_choices directly.
func _available_choices() -> Array:
	var value := _affinity_value()
	var out: Array = []
	for choice in DialogueDB.node_choices(_current_node()):
		if choice is Dictionary and DialogueDB.choice_available(choice, value):
			out.append(choice)
	return out


## The current node with its choices replaced by the available ones, so the pure
## DialogueDB.advance_from() can be reused verbatim on the list the player actually sees. A
## shallow duplicate: the cached node in dialogue_db.gd's dictionary is never mutated.
func _filtered_node() -> Dictionary:
	var node := _current_node()
	if not node.has("choices"):
		return node
	var filtered := node.duplicate()
	filtered["choices"] = _available_choices()
	return filtered


func _is_fully_revealed() -> bool:
	return DialogueDB.visible_chars(_full_text.length(), maxf(_elapsed, 0.001), chars_per_second()) \
		>= _full_text.length()


## The reveal speed: the "Text speed" setting (scripts/settings.gd), CHARS_PER_SECOND without it.
## Instant reads as a speed no line can outrun.
func chars_per_second() -> float:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return CHARS_PER_SECOND
	var cps := float(settings.text_chars_per_second())
	return cps if cps > 0.0 else 1.0e9


func _refresh_body() -> void:
	var count := DialogueDB.visible_chars(_full_text.length(), maxf(_elapsed, 0.001), chars_per_second())
	body_label.text = _full_text.substr(0, count)
	var revealed := _is_fully_revealed()
	hint_label.text = "" if not revealed else _hint_text()
	# Choices are populated as soon as their node loads (_refresh_choices, below) but only shown
	# once the line has finished typing — matching hint_label's own reveal-gated visibility, and
	# avoiding the odd read of a response menu appearing mid-sentence.
	choices_box.visible = revealed and not _available_choices().is_empty()


func _hint_text() -> String:
	var settings := get_node_or_null("/root/Settings")
	var go := String(settings.prompt("use_tool")) if settings != null else "Space"
	var nav := String(settings.nav_prompt()) if settings != null else "Up/Down"
	if not _available_choices().is_empty():
		return "%s to choose, %s to confirm" % [nav, go]
	return "%s to continue" % go


func _refresh_choices() -> void:
	var choices := _available_choices()
	for i in _choice_labels.size():
		var label := _choice_labels[i]
		if i < choices.size():
			label.visible = true
			label.text = DialogueDB.fill(String(choices[i].get("text", "")), {})
			label.add_theme_color_override("font_color",
				CHOICE_SELECTED_COLOR if i == _choice_index else CHOICE_COLOR)
		else:
			label.visible = false
