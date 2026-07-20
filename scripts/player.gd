extends CharacterBody2D
## The player character: 4-directional movement on a CharacterBody2D, with idle / walk /
## tool-use animations per facing direction (Phase 2), plus Phase 3's real farming-tool
## dispatch, energy economy, and pass-out-at-zero transition.
##
## Tool-use (ROADMAP Phase 3): pressing "use_tool" always plays the generic swing animation
## (per CLAUDE.md's scope call — one shared swing reused for all 5 tools rather than
## per-tool PixelLab animations) and resolves ONE interaction against the tile directly ahead
## of the player, in priority order:
##   1. A mature crop there is always harvested, regardless of what's selected in the hotbar
##      (Stardew convention: harvesting isn't tool-gated).
##   2. Otherwise, the selected hotbar item decides: Hoe tills, Watering Can waters, Axe chops
##      a tree node, Pickaxe mines an ore node, a Seed item plants (consuming one seed) on
##      tilled bare soil. Anything else (Bag, empty hotbar slot, wrong tool for the tile) is a
##      no-op swing — animation plays, nothing happens, no energy spent.
## A broken tool (durability hit 0) is treated as "nothing selected" for effect purposes — it
## stays in the inventory (no repair system exists yet) but stops doing anything until a later
## phase adds one; see scripts/inventory.gd's damage_selected_tool().
##
## Holding "use_tool" down repeats the swing automatically (Stardew convention — a held tool
## button keeps tilling/watering/chopping as fast as the animation allows, not just once per
## press): _physics_process polls Input.is_action_pressed() every physics frame rather than
## reacting only to the press *event*, and re-fires use_tool() the instant the previous swing's
## using_tool lock clears, for as long as the button stays held.
##
## The INSTANT interactions in use_tool()'s dispatch (chest, bed, shipping box, NPC dialogue)
## are the exception: they fire once per discrete press, never on held-key repeat (playtest
## bug-fix, 2026-07-10 — a held/tapped key spanning several 60fps physics frames used to sleep
## multiple days at once, and re-open a just-closed dialogue/store/shipping UI). The gate is
## the _instant_armed press-edge latch below, NOT Input.is_action_just_pressed(): just-pressed's
## one-physics-frame window lands on the frame AFTER the input system dispatched the same press
## to _unhandled_input (verified empirically with a parse_input_event probe), so a press that a
## modal UI consumed to close itself would still read just-pressed on the next poll and re-open
## the interaction. The latch re-arms only on release, and a press held while (or in the frame
## after) any modal surface was open never counts — see instant_armed_next().

const Inventory := preload("res://scripts/inventory.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const DayManagerScript := preload("res://scripts/day_manager.gd")

signal energy_changed(current: float, max_energy: float)
## Phase 5 Stage 1: fired instead of handling the interaction locally (see use_tool()'s priority
## dispatch) so scripts/dialogue_ui.gd can own opening the box — mirrors structures.gd's
## chest_toggled -> hud.toggle_chest_ui() signal wiring rather than a direct method call, keeping
## player.gd instance-testable (tests/test_player.gd) without a real DialogueUI scene existing.
signal npc_dialogue_requested(npc: Node)
## Phase 5 Stage 2: fired on any Credits balance change (a purchase, or a Stage 3 shipping-box
## sale credit) — hud.gd's currency display binds to this the same way it binds
## energy_changed, so the balance's one owner (this field) never needs a UI reference.
signal credits_changed(current: int)
## Phase 5 Stage 3: fired instead of handling the shipping-box interaction locally — same
## signal-handoff shape as npc_dialogue_requested above; main.gd wires it to
## scripts/shipping_ui.gd's open_box(). No payload: there's exactly one box per map, and the
## UI reads everything it needs from the player/structures references it was bound with.
signal shipping_box_requested
## Zone split: fired when the player steps onto a zone-transition gate cell (see the
## _zone_transitioning block in _physics_process). main.gd owns the response — the fade +
## _bind_zone rebind/teleport — same signal-handoff shape as the interactions above.
signal zone_exit_requested(target_zone: String, entry_cell: Vector2i)

## ~3.5 tiles/second at the 16px tile size — close to Stardew's walk feel.
const SPEED := 56.0
const CELL_SIZE := 16.0

## Per-action energy costs (ROADMAP Phase 3: "actions cost energy", replacing Phase 2's flat
## TOOL_USE_ENERGY_COST stub with real per-action pricing).
##
## Tuned against Stardew Valley's actual pacing rather than picked arbitrarily: base Stardew
## tool use costs ~2 energy out of a 270 starting max (~0.7% of the bar per swing), letting a
## player till/water dozens of tiles per day. The original Phase 3 pass used 4/2/1/1/5/5 against
## our 100 max energy (a 4% hit per till alone) which drained many times faster than Stardew's
## feel -- reported and fixed same-day. These values keep the same *relative* costs between
## actions (till/water heaviest, plant/harvest lightest, chop/mine heaviest of all) while
## matching Stardew's ~1% per basic action against our smaller 100-point bar.
const ENERGY_TILL := 1.0
const ENERGY_WATER := 1.0
const ENERGY_PLANT := 0.5
const ENERGY_HARVEST := 0.5
const ENERGY_CHOP := 1.5
const ENERGY_MINE := 1.5
## Phase 4 Stage 2: confirming a building placement (scripts/builder.gd). Priced between
## watering (1.0) and chopping (1.5) — staking out a construction site is real physical work,
## heavier than a watering pass but lighter than felling a tree, and it's a one-off per building
## rather than a per-tile repeated action, so it shouldn't dominate the day's energy budget.
const ENERGY_BUILD := 1.25

## -- Night rules (2026-07-11, Stardew-style forced sleep — direct playtest feedback from
##    Sarvesh, new scope beyond ROADMAP Phase 3's original energy entry; see GDD.md §4 "The
##    night rules" and ROADMAP.md Phase 3's enhancement note) --
##
## The day counter rolls at midnight (day_manager.gd), so "up past midnight" reads as
## minutes_into_day in [0, DAY_START_MINUTES) — a range every sleep transition skips over
## (they land exactly AT 6 AM), making it reachable only by staying awake.
##
## 1. From midnight, the player is getting sleepy: a passive energy drain ticks alongside the
##    clock (late_night_drain below), on top of the per-action costs — the energy bar visibly
##    slides even while standing still, paired with hud.gd's pulsing "GETTING SLEEPY..." cue.
## 2. At 2:00 AM the player passes out where they stand REGARDLESS of remaining energy
##    (should_force_passout below) — a second, independent trigger from Phase 3's
##    zero-energy rule, keyed on time-of-day, not the energy value.
## 3. A stay-awake consumable (items.json's "coffee", the one item with "stay_awake": true)
##    suppresses that night's 2 AM cutoff. The charge lasts exactly one night: it's consumed
##    by surviving to 6 AM awake (survived_night below) and cleared by any sleep/pass-out, so
##    a full-24-hours-awake run still collapses at the NEXT 2 AM, per the spec. The passive
##    drain continues regardless — coffee beats the clock, not the fatigue.
##
## FORCED_PASSOUT_MINUTES: 2:00 AM as minutes_into_day. SLEEPY_DRAIN_PER_GAME_MINUTE: tuned so
## the midnight-to-2-AM stretch costs 18 energy (120 game-minutes x 0.15 = 18% of the 100 bar)
## — clearly visible on the HUD bar over the 2 real minutes that window lasts, a real price for
## late-night work, but never lethal by itself from a healthy evening's reserve (the 2 AM rule,
## not the drain, is what ends the night).
const FORCED_PASSOUT_MINUTES := 2.0 * 60.0
const SLEEPY_DRAIN_PER_GAME_MINUTE := 0.15

const FACINGS := ["south", "north", "east", "west"]
const FACING_VECTORS := {
	"south": Vector2(0, 1),
	"north": Vector2(0, -1),
	"east": Vector2(1, 0),
	"west": Vector2(-1, 0),
}

var facing := "south"
## Phase 8 Stage 1: pulled out as a named constant so BuildingEffects.recompute_capacity_unlocks'
## "energy_max" bonus (the Clinic) has a stable base to add on top of — main.gd recomputes
## max_energy as BASE_MAX_ENERGY + that bonus (never incrementally mutated), so completing a
## second Clinic, reloading a save, or anything else re-deriving the total can never drift from
## the live count of completed Clinics.
const BASE_MAX_ENERGY := 100.0
var max_energy := BASE_MAX_ENERGY
var energy := max_energy
## Phase 5 Stage 2: the player's Credits balance (GDD.md §7 — settled humanity's currency, not
## the earlier-drafted "Scrap Coins"). Starts at 0, deliberately: nothing grants Credits yet
## (Stage 3's shipping box is the actual earning mechanism, next session) — a fresh player
## legitimately can't afford anything at Marta's store until they've sold a first harvest, which
## is the intended shape of "Economy loop is closed" only once the whole phase (both stages)
## lands. See add_credits()/set_credits() below for Stage 3's hook to credit a sale.
var credits := 0
var using_tool := false

## Night rules: true after drinking coffee (or any future "stay_awake" item) — suppresses
## tonight's 2 AM forced pass-out. See the night-rules const block above for the full lifecycle
## (consumed at 6 AM awake, cleared by any sleep/pass-out). Deliberately NOT saved: every save
## is written by _end_day(), which has just cleared it — a save can never legitimately carry a
## live charge.
var stay_awake_tonight := false

## Press-edge latch for use_tool()'s instant interactions (see class doc). True means the next
## poll frame that finds the button down may fire an instant interaction; consumed (set false)
## the moment the poll fires use_tool(), re-armed only by seeing the button up. Starts armed so
## the very first press works.
var _instant_armed := true
## Whether any modal surface (dialogue/store/shipping/build mode) was active on the PREVIOUS
## physics frame — a press first observed on the frame right after a modal closed belongs to
## that modal (it's the press that closed it, dispatched between physics frames), so the latch
## must treat it as consumed. See instant_armed_next().
var _modal_open_last_frame := false

## Till-and-advance stepping (see class doc): a short, grid-snapped move to the next cell,
## queued between swings when a direction is held alongside "use_tool" so holding both
## advances tile-by-tile like Stardew's auto-work-and-walk, instead of repeating in place.
var _stepping := false
var _step_target := Vector2.ZERO

## -- Zone split bookkeeping --
## Which zone the player currently stands in ("farm"/"path"/"town"/"ranch") — kept by main.gd's
## _bind_zone_refs and saved/restored (v2 saves' player.current_zone).
var current_zone_id := "farm"
## ALL FOUR zones' nodes ({zone_id: {map, farm, structures, npcs}}), set once by main.gd at
## boot. Distinct from the per-transition farm/test_map/structures/npcs fields below, which
## always point at the CURRENT zone's nodes only (rebound on every transition) — this dict is
## for whole-world operations, i.e. _end_day's save gather.
var zones: Dictionary = {}
## True from the instant a gate-cell exit is detected until main.gd's _bind_zone completes the
## rebind at the fade's black midpoint. Movement/input freezes for the duration, matching every
## other modal state — and critically, the exit detection itself stands down: the fade leaves
## the player standing ON the gate cell for ~0.075s of physics frames, which would otherwise
## re-detect the exit and re-emit zone_exit_requested every frame, corrupting the fade tween.
var _zone_transitioning := false

## Bound by main.gd once the world exists (see bind_world()).
var farm: Node = null
var test_map: Node = null
var structures: Node = null
## Phase 4 Stage 2: the build/placement-mode node (scripts/builder.gd), also bound by main.gd.
## While its mode is active, "use_tool" means "confirm placement" (handled there), so the
## held-swing polling below stands down — see _in_build_mode().
var builder: Node = null
## Phase 5 Stage 1: the NPC roster (scripts/npcs.gd) — bound by main.gd like farm/test_map/
## structures above, used by use_tool()'s priority dispatch to find an NPC directly ahead.
var npcs: Node = null
## Phase 5 Stage 1: the dialogue box (scripts/dialogue_ui.gd), bound DIRECTLY by main.gd
## (not via bind_world) the same way player.builder is — while it's open, _physics_process
## freezes entirely (see _in_dialogue()) and dialogue_ui.gd owns "use_tool" itself (via its own
## _unhandled_input) to advance/close the conversation.
var dialogue_ui: Node = null
## Phase 5 Stage 2: Marta's store (scripts/store_ui.gd), bound DIRECTLY by main.gd the same way
## dialogue_ui is above — while it's open, _physics_process freezes entirely (see _in_store())
## and store_ui.gd owns "use_tool"/"move_up"/"move_down" itself to browse/buy/leave.
var store_ui: Node = null
## Phase 5 Stage 3: the shipping box's crop-loading UI (scripts/shipping_ui.gd), bound DIRECTLY
## by main.gd exactly like store_ui above, with the identical freeze rule (see _in_shipping()).
var shipping_ui: Node = null
## 2026-07-12: the in-game tabbed menu (scripts/menu_screen.gd), bound DIRECTLY by main.gd
## exactly like the three UIs above, with the identical freeze rule (see _in_menu()) — the menu
## owns "toggle_inventory"/"build_cycle"/"use_tool"/"ui_cancel" itself while open.
var menu_screen: Node = null
var inventory: Inventory = Inventory.new()

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_play("idle")
	_give_starting_loadout()
	# Night rules: ride the clock's lived-time signal (time_advanced — see its doc in
	# day_manager.gd for why NOT time_changed: sleep transitions and save-loads teleport the
	# clock without emitting it, so they can never read as time spent awake) rather than polling
	# in _physics_process. The drain/2 AM checks inherit time_paused's semantics for free — a
	# paused clock (dialogue/store/shipping open, per main.gd's _process poll) advances nothing
	# and emits nothing, so 2 AM literally cannot arrive mid-conversation. (Those are the same
	# question: the cutoff is a fact about the clock, and the clock is frozen.) Build mode
	# doesn't pause time, so the night catches a player who ignores it while placing blueprints
	# — same as it always could via the zero-energy rule when a placement's ENERGY_BUILD landed
	# on an empty bar.
	DayManager.time_advanced.connect(_on_time_advanced)


func _physics_process(_delta: float) -> void:
	# The instant-interaction press-edge latch runs before every early return below, so it
	# tracks the button across swing-lock frames and modal-frozen frames alike (a release+press
	# during a swing still arms; a press held into/through a modal never does).
	var modal_open := _in_dialogue() or _in_store() or _in_shipping() or _in_build_mode() \
		or _in_menu()
	_instant_armed = instant_armed_next(_instant_armed,
		Input.is_action_pressed("use_tool"), modal_open, _modal_open_last_frame)
	_modal_open_last_frame = modal_open
	if using_tool:
		velocity = Vector2.ZERO
		return
	# Phase 5 Stage 1: a conversation freezes the player completely (movement AND tool-swing
	# polling) for as long as it's open — dialogue_ui.gd owns "use_tool" itself via its own
	# _unhandled_input to advance/close, so this loop must not also react to the same held key.
	# Checked ahead of everything below (not folded into the use_tool-repeat branch's condition
	# the way _in_build_mode() is) specifically because build mode still lets the player walk to
	# reposition the preview, but a dialogue must NOT — the player should read as genuinely stuck
	# in the conversation, not free to wander off mid-sentence.
	if _in_dialogue():
		velocity = Vector2.ZERO
		return
	# Phase 5 Stage 2: browsing Marta's store freezes the player exactly like a conversation does
	# (see _in_dialogue()'s comment above) — store_ui.gd owns "use_tool"/"move_up"/"move_down"
	# itself via its own _unhandled_input to browse/buy/leave, so this loop must stand down too.
	if _in_store():
		velocity = Vector2.ZERO
		return
	# Phase 5 Stage 3: loading the shipping box, same freeze rule as the store/dialogue above.
	if _in_shipping():
		velocity = Vector2.ZERO
		return
	# 2026-07-12: the tabbed in-game menu, same freeze rule again — menu_screen.gd owns
	# "use_tool" (Save & Return confirm) and "build_cycle" (tab switch) while it's open, so
	# this loop must stand down completely.
	if _in_menu():
		velocity = Vector2.ZERO
		return
	# Zone split: while a gate crossing's fade is in flight, freeze completely (see the
	# _zone_transitioning field doc — without this, the player still standing on the gate cell
	# during the fade-out half would re-detect the exit below every physics frame). Cleared by
	# main.gd's _bind_zone via end_zone_transition() at the fade's black midpoint, once the
	# player already stands in the new zone.
	if _zone_transitioning:
		velocity = Vector2.ZERO
		return
	# Standing on a zone-transition gate cell requests the warp exactly once per crossing.
	# The test_map guard keeps this node instance-testable without a bound world, same as the
	# use_tool dispatch's own guards.
	if test_map != null:
		var exit: Dictionary = test_map.zone_exit_at(test_map.world_to_cell(global_position))
		if not exit.is_empty():
			_zone_transitioning = true
			velocity = Vector2.ZERO
			zone_exit_requested.emit(String(exit["target_zone"]), Vector2i(exit["entry_cell"]))
			return
	if _stepping:
		_process_step()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_pressed("use_tool") and not _in_build_mode():
		# Held-button repeat (see class doc): re-triggers every physics frame the button is
		# down and the previous swing has finished, since use_tool() re-locks using_tool
		# immediately and this branch is unreachable again until that lock clears. Facing
		# follows a held direction so the swing lands on the tile you're steering toward, not
		# wherever you happened to be facing before.
		velocity = Vector2.ZERO
		if input != Vector2.ZERO:
			facing = facing_from_input(input, facing)
		# Instant interactions fire only on the discrete press edge (see class doc); consume the
		# latch so the frames the key stays physically down can't re-fire a chest toggle, a bed
		# sleep, or a just-closed dialogue/store/shipping UI. The swing path is untouched — its
		# repeat is governed by the using_tool lock, exactly as before.
		var instant_allowed := _instant_armed
		_instant_armed = false
		use_tool(instant_allowed)
		return
	velocity = input * SPEED
	move_and_slide()
	facing = facing_from_input(input, facing)
	_play("walk" if input != Vector2.ZERO else "idle")


## Advances one grid cell toward _step_target at normal walk speed, then hands control back to
## the use_tool-repeat branch above. Bails out early (rather than getting stuck) if something
## physically blocks the step, e.g. rubble or a resource node revealed by the tile just cleared.
func _process_step() -> void:
	var to_target := _step_target - global_position
	if to_target.length() <= 1.0:
		global_position = _step_target
		_stepping = false
		return
	velocity = to_target.normalized() * SPEED
	move_and_slide()
	_play("walk")
	if get_slide_collision_count() > 0:
		_stepping = false


func _unhandled_input(event: InputEvent) -> void:
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_slot_%d" % (i + 1)):
			inventory.select_hotbar(i)


## Wired by main.gd once the farm/map/structures exist, so player.gd can stay instance-testable
## on its own (tests/test_player.gd) without needing a full scene. structures_node/npcs_node are
## optional (default null) so existing callers/tests keep working unchanged.
func bind_world(farm_node: Node, map_node: Node, structures_node: Node = null,
		npcs_node: Node = null) -> void:
	farm = farm_node
	test_map = map_node
	structures = structures_node
	npcs = npcs_node


## Plays the shared swing animation and resolves the tile interaction. Locks movement for the
## animation's duration exactly like the Phase 2 stub did.
##
## instant_allowed (playtest bug-fix, 2026-07-10): whether the four INSTANT interaction branches
## below (chest/bed/shipping box/NPC) may fire. The held-key poll in _physics_process passes the
## press-edge latch's state here, so those branches fire once per discrete press instead of every
## physics frame the key stays down — while direct callers (tests, tools) default to true and
## behave exactly as before. When an instant target sits ahead but the press edge is spent, the
## call is a no-op rather than a fallthrough: a held tool button walking past a chest must not
## start swinging AT the chest either (the instant targets always preempted the swing dispatch).
func use_tool(instant_allowed: bool = true) -> void:
	if energy <= 0.0:
		return
	# Phase 4: chest interaction is instant (no energy cost, no tool-swing lock/animation) and
	# takes priority over farming — matches Stardew's "activate button opens a chest" convention
	# rather than routing through the hotbar-tool dispatch below. Stage 2 generalized "the chest"
	# to any storage cell (layout chest OR a completed player-built Storage Shed), so the target
	# cell is passed through for structures.gd to resolve which Inventory lives there.
	if structures != null and test_map != null and structures.is_chest_at(_target_cell()):
		if instant_allowed:
			structures.interact_chest(_target_cell())
		return
	# Phase 4 Stage 3: the farmhouse bed — same instant, energy-free, queue-jumping interaction
	# shape as the chest above. Sleeping ends the day (auto-saving as it does — see checklist
	# item "Auto-save at end of day"), so it deliberately never routes through the tool dispatch.
	if structures != null and test_map != null and structures.is_bed_at(_target_cell()):
		if instant_allowed:
			_sleep_in_bed()
		return
	# Phase 5 Stage 3: the shipping box — same instant, energy-free, queue-jumping shape as the
	# chest/bed above, handed off via a signal like NPC dialogue below (the loading UI needs the
	# player's inventory and the box's contents, so scripts/shipping_ui.gd owns the interaction).
	if structures != null and test_map != null and structures.is_shipping_box_at(_target_cell()):
		if instant_allowed:
			shipping_box_requested.emit()
		return
	# Phase 5 Stage 1: an NPC directly ahead — same instant, energy-free, queue-jumping shape as
	# the chest/bed above, but the interaction itself (opening the dialogue box) is handed off via
	# a signal rather than resolved here, since it belongs to scripts/dialogue_ui.gd (see the
	# signal's own doc comment above for why).
	if npcs != null and test_map != null:
		var npc: Node = npcs.npc_at(_target_cell())
		if npc != null:
			if instant_allowed:
				npc_dialogue_requested.emit(npc)
			return
	using_tool = true
	velocity = Vector2.ZERO
	_play("tool")
	if farm != null and test_map != null:
		_interact(_target_cell())


## Applies a delta to energy (clamped 0..max) and fires pass-out if it just crossed to zero.
func set_energy(value: float) -> void:
	var result := apply_energy_delta(energy, max_energy, value - energy)
	energy = result["energy"]
	energy_changed.emit(energy, max_energy)
	if result["passed_out"]:
		_pass_out()


## Night-rules driver, connected to DayManager.time_advanced in _ready() (see the comment there
## for why that signal, not time_changed or a poll). Runs the pure rules below against exactly
## the interval the clock lived through: applies the post-midnight sleepy drain, fires the 2 AM
## forced pass-out, and retires a spent stay-awake charge at 6 AM.
func _on_time_advanced(prev_minutes: float, new_minutes: float) -> void:
	var drained := late_night_drain(prev_minutes, new_minutes, SLEEPY_DRAIN_PER_GAME_MINUTE)
	if drained > 0.0:
		# May itself hit zero and fire the zero-energy pass-out, which jumps the clock to 6 AM
		# — hence re-reading the LIVE clock below rather than trusting this emission's
		# new_minutes: after such a pass-out the live value reads 6:00 AM (outside the band)
		# and the 2 AM check correctly stands down instead of double-firing.
		set_energy(energy - drained)
	var now: float = DayManager.minutes_into_day
	if should_force_passout(now, stay_awake_tonight):
		_pass_out()
	elif stay_awake_tonight and survived_night(prev_minutes, now):
		stay_awake_tonight = false  # the charge bought exactly one night — see the const block


## Stardew's "passing out loses the rest of the day" rule, now with two independent triggers:
## energy hitting zero at any hour (ROADMAP Phase 3, via set_energy's crossing check) and the
## clock reaching 2 AM with the player still awake (2026-07-11 forced-sleep rules, via
## _on_time_changed above) — the latter fires REGARDLESS of the energy value. Waking up
## restores full energy, same as collapsing in Stardew.
##
## Save-on-pass-out (2026-07-11): collapsing now auto-saves exactly like the bed does, per
## Sarvesh's explicit forced-sleep spec ("all progress saved when the player falls asleep OR
## passes out"). The old no-save behaviour was a deliberate, documented Phase 4 Stage 3 choice
## (only the checklist's bed interaction was to auto-save), not an oversight — but the spec
## supersedes it: with a nightly 2 AM collapse in the game, "passed out past midnight, lost the
## whole session's progress" would be brutal, and Stardew itself saves on collapse too.
func _pass_out() -> void:
	_end_day()


## Phase 4 Stage 3: sleeping in the farmhouse bed (structures.is_bed_at). Deliberately
## indistinguishable from _pass_out() since the save-on-pass-out change above — both are
## "the night ends here"; only the trigger differs. Kept as separate named methods so call
## sites keep reading correctly (use_tool's bed branch vs. the two pass-out rules).
func _sleep_in_bed() -> void:
	_end_day()


## The one way a day ends, whatever ended it: jump to 6 AM through the same day_started signal
## path (crop growth, construction completion, shipping sales all fire identically — and
## skip_to_next_morning() itself knows an after-midnight ending must not double-tick them),
## restore full energy ("waking up rested"), retire any stay-awake charge, THEN auto-save —
## after the day advance, so the save captures the fresh morning the player wakes into on
## reload, not the stale end of the old night. GameState.save_game emits game_saved on success,
## which the HUD's "WORLD SAVED" notice rides. The world-refs guard keeps this node
## instance-testable without a bound world (bind_world is main.gd's job), matching
## _interact()'s own farm/test_map guard. Note there is deliberately no re-entrancy guard:
## skip_to_next_morning() emits time_changed (HUD-facing) but never time_advanced, so the
## sleep jump itself can't land back in _on_time_advanced as phantom lived time.
func _end_day() -> void:
	stay_awake_tonight = false
	DayManager.skip_to_next_morning()
	energy = max_energy
	energy_changed.emit(energy, max_energy)
	if not zones.is_empty():
		GameState.save_game(self, zones)


## True while scripts/builder.gd's placement mode is active — the use_tool button then belongs
## to placement confirmation (handled in builder.gd's _unhandled_input), not tool swings.
func _in_build_mode() -> bool:
	return builder != null and bool(builder.active)


## True while scripts/dialogue_ui.gd's box is open — see _physics_process's early-return.
func _in_dialogue() -> bool:
	return dialogue_ui != null and bool(dialogue_ui.active)


## True while scripts/store_ui.gd's box is open — see _physics_process's early-return.
func _in_store() -> bool:
	return store_ui != null and bool(store_ui.active)


## True while scripts/shipping_ui.gd's box is open — see _physics_process's early-return.
func _in_shipping() -> bool:
	return shipping_ui != null and bool(shipping_ui.active)


## True while scripts/menu_screen.gd's tabbed menu is open — see _physics_process's early-return.
func _in_menu() -> bool:
	return menu_screen != null and bool(menu_screen.active)


## Called by main.gd's _bind_zone once a zone crossing's rebind/teleport has completed (at the
## fade's black midpoint) — the one legitimate release of the _zone_transitioning freeze.
func end_zone_transition() -> void:
	_zone_transitioning = false


## The logical cell directly ahead of the player, in the current facing direction.
func _target_cell() -> Vector2i:
	var dir: Vector2 = FACING_VECTORS.get(facing, Vector2(0, 1))
	return test_map.world_to_cell(global_position + dir * CELL_SIZE)


func _interact(cell: Vector2i) -> void:
	if farm.can_harvest(cell):
		var result: Dictionary = farm.harvest(cell)
		if not result.is_empty():
			_grant_item(result)
			set_energy(energy - ENERGY_HARVEST)
		return

	var slot := inventory.get_selected_slot()
	var item_id := String(slot.get("item_id", ""))
	if slot.has("durability") and int(slot["durability"]) <= 0:
		item_id = ""  # broken tool: swing does nothing

	match item_id:
		"hoe":
			if farm.can_till(cell) and farm.till(cell):
				set_energy(energy - ENERGY_TILL)
				inventory.damage_selected_tool()
		"watering_can":
			if farm.can_water(cell) and farm.water(cell):
				set_energy(energy - ENERGY_WATER)
				inventory.damage_selected_tool()
		"axe":
			if farm.can_chop(cell):
				for result in farm.chop(cell):
					_grant_item(result)
				set_energy(energy - ENERGY_CHOP)
				inventory.damage_selected_tool()
		"pickaxe":
			if farm.can_mine(cell):
				for result in farm.mine(cell):
					_grant_item(result)
				set_energy(energy - ENERGY_MINE)
				inventory.damage_selected_tool()
		_:
			if ItemDB.is_seed(item_id) and farm.can_plant(cell):
				var crop_id := String(ItemDB.get_item(item_id).get("crop_id", ""))
				if farm.plant(cell, crop_id):
					inventory.remove_item(item_id, 1)
					set_energy(energy - ENERGY_PLANT)
			elif ItemDB.is_edible(item_id):
				# Eating (2026-07-11, built as the general case the coffee mechanic hangs off):
				# a selected food item + use_tool consumes one for its effect, the same shape as
				# planting a seed above — items.json's energy_restored field had sat unused
				# since Phase 3 with no way to eat anything. Costs no energy (it GRANTS energy),
				# plays the same shared swing (an "eating" animation is Phase 6-art-pass scope,
				# not worth a new PixelLab call for this session). Note the priority order the
				# dispatch already imposes: facing a mature crop harvests instead (Stardew-
				# faithful "harvest isn't tool-gated" wins) — step off the crop row to snack.
				_consume_food(item_id)


## Consumes one of the selected food item for its effects: energy_restored lands via
## set_energy's clamp (eating at a nearly-full bar wastes the overflow, Stardew-style), and a
## "stay_awake" item (coffee) arms tonight's 2 AM suppression. Effects apply only if the
## removal actually happened — an inventory desync must never grant a free meal.
func _consume_food(item_id: String) -> void:
	if inventory.remove_item(item_id, 1) != 1:
		return
	if ItemDB.grants_stay_awake(item_id):
		stay_awake_tonight = true
	var restored := ItemDB.energy_restored(item_id)
	if restored > 0:
		set_energy(energy + float(restored))


## -- Credits (Phase 5 Stage 2) --

## Sets the Credits balance directly (clamped at 0 — a purchase must never be allowed to drive it
## negative, and there's no legitimate way to owe Credits in this game). Used both by
## scripts/store_ui.gd after a successful purchase (fed shop_db.gd's pure attempt_purchase()
## result) and available as the general "set the balance" primitive load_state() below also uses.
func set_credits(value: int) -> void:
	credits = maxi(0, value)
	credits_changed.emit(credits)


## Stage 2's documented hook, now live: main.gd wires structures.gd's crops_sold(total) signal
## straight here, so a shipping-box sale credits the balance with no new subsystem — exactly the
## path that comment promised Stage 3 would use.
func add_credits(amount: int) -> void:
	set_credits(credits + amount)


## Phase 8 Stage 1: main.gd wires structures.gd's building_yield_produced(items) signal straight
## here — the generalized-dispatch counterpart of add_credits() above, letting any zone's daily
## building yield (Workshop's scrap, Greenhouse's seedling, Community Kitchen's meal, ...) land
## in the backpack with no per-building code in player.gd. Overflow is silently lost exactly like
## _grant_item()'s harvest/gather path (Phase 3 has no ground-drop system yet).
func add_items(items: Dictionary) -> void:
	for item_id in items:
		inventory.add_item(String(item_id), int(items[item_id]))


## -- Save/load (Phase 4 Stage 3; see scripts/save_data.gd's class doc for the shape) --

func save_state() -> Dictionary:
	return {
		# Vector2 split into JSON-friendly scalars. WORLD-space (includes the current zone's
		# position offset), so restoring x/y + current_zone reproduces the exact stand-point.
		"x": global_position.x,
		"y": global_position.y,
		"facing": facing,
		"energy": energy,
		"credits": credits,
		"current_zone": current_zone_id,
		"inventory": SaveData.encode_inventory(inventory.slots, inventory.selected_hotbar_index),
	}


func load_state(data: Dictionary) -> void:
	global_position = Vector2(float(data.get("x", global_position.x)),
		float(data.get("y", global_position.y)))
	velocity = Vector2.ZERO
	# Zone split: which zone the save was written in — main.gd's _apply_save reads this back
	# (via _bind_zone_refs) right after load_state, so the world refs follow the position.
	current_zone_id = String(data.get("current_zone", "farm"))
	if String(data.get("facing", "")) in FACINGS:
		facing = String(data["facing"])
	# Direct assign + emit, not set_energy(): restoring a saved value is not a gameplay energy
	# change and must never re-trigger the pass-out rule (set_energy's crossing check would be
	# safe for the values a bed save writes, but load shouldn't depend on that).
	energy = clampf(float(data.get("energy", max_energy)), 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
	# Direct assign + emit, not set_credits(): same reasoning as energy above — restoring a saved
	# balance is not a purchase and set_credits()'s clamp is a no-op for any value a real save
	# ever wrote anyway (int(...) already can't be negative coming out of save_state()).
	credits = int(data.get("credits", 0))
	credits_changed.emit(credits)
	var inventory_data = data.get("inventory", {})
	if inventory_data is Dictionary and not (inventory_data as Dictionary).is_empty():
		var decoded := SaveData.decode_inventory(inventory_data)
		inventory.restore(decoded["slots"], int(decoded["selected_hotbar_index"]))
	# Note for the night rules: main.gd's _apply_save teleports DayManager's clock directly
	# (no advance_minutes), so a resume never emits time_advanced for the jump — no phantom
	# sleepy drain on the first tick after a load, with zero bookkeeping needed here.
	_play("idle")


## Overflow (backpack full) is silently lost — Phase 3 has no ground-drop system yet; a known,
## documented limitation (see the Phase 3 report) rather than an oversight.
func _grant_item(result: Dictionary) -> void:
	inventory.add_item(String(result.get("item_id", "")), int(result.get("count", 0)))


## Starting loadout: the 5 tools in hotbar slots 0-4 (fixed order matching the checklist), a
## handful of Mutant Potato seeds in slot 5 to plant immediately. Everything else starts empty.
func _give_starting_loadout() -> void:
	for tool_id in ["hoe", "watering_can", "axe", "pickaxe", "bag"]:
		inventory.add_item(tool_id, 1, ItemDB.durability_max(tool_id))
	inventory.add_item("seed_mutant_potato", 5)


## Pure facing rule (testable headlessly): horizontal input wins on diagonals (Stardew-style
## side-facing bias), and facing is retained when input stops so idle keeps the last direction.
static func facing_from_input(input: Vector2, current: String) -> String:
	if input == Vector2.ZERO:
		return current
	if absf(input.x) >= absf(input.y) and input.x != 0.0:
		return "east" if input.x > 0.0 else "west"
	return "south" if input.y > 0.0 else "north"


## Pure press-edge latch rule for use_tool()'s instant interactions (testable headlessly, no
## Node/scene required — see the class doc's held-key section for why this exists instead of
## Input.is_action_just_pressed). Given the latch's previous state, whether "use_tool" reads
## pressed this physics frame, and whether any modal surface is open now / was open on the
## previous physics frame, returns the latch's new state BEFORE the poll consumes it:
##   - button up  -> re-arm (a fresh press is a fresh edge), regardless of modal state;
##   - button down with a modal open now OR last frame -> disarm (that press belongs to the
##     modal UI — including the press that just closed it, which the input system dispatched
##     to _unhandled_input between physics frames);
##   - button down otherwise -> carry the previous state (armed until the poll consumes it).
static func instant_armed_next(armed: bool, pressed: bool, modal_open: bool,
		modal_was_open: bool) -> bool:
	if not pressed:
		return true
	if modal_open or modal_was_open:
		return false
	return armed


## Pure energy math (testable headlessly, no Node/scene required): clamps current+delta into
## [0, max_energy] and reports whether this change is the one that crossed from positive energy
## down to exactly zero (i.e. should trigger a pass-out) — a delta applied while already at 0
## does NOT re-trigger, matching set_energy()'s guard.
static func apply_energy_delta(current: float, max_energy_value: float, delta: float) -> Dictionary:
	var new_energy := clampf(current + delta, 0.0, max_energy_value)
	var passed_out := current > 0.0 and new_energy <= 0.0
	return {"energy": new_energy, "passed_out": passed_out}


## -- Night rules, pure parts (testable headlessly — see the const block up top for design) --

## Sleepy-drain integration: how much energy one clock tick from prev_minutes to new_minutes
## costs, i.e. `rate` per game-minute of overlap between the tick's traversal and the
## midnight-to-6-AM window [0, DAY_START_MINUTES). Handles the tick that wraps midnight
## (new < prev: only the post-midnight portion is in the window — the pre-midnight remainder of
## the old day never is, since the window starts AT the wrap). A tick spanning multiple whole
## days isn't integrated beyond one window's worth; real play advances ~0.017 minutes per frame
## and only test tooling ever jumps further.
static func late_night_drain(prev_minutes: float, new_minutes: float, rate: float) -> float:
	var window_end := float(DayManagerScript.DAY_START_MINUTES)
	if new_minutes >= prev_minutes:
		return maxf(0.0, minf(new_minutes, window_end) - minf(prev_minutes, window_end)) * rate
	return minf(new_minutes, window_end) * rate


## The 2 AM rule: whether a clock reading, seen while the player is awake, forces a pass-out.
## A state check, not an edge check, on purpose: the [2 AM, 6 AM) band is unreachable except by
## being awake in it (every sleep transition lands exactly AT 6 AM, and saves are only written
## there), so "the awake clock reads 2-something" IS the violation — no crossing bookkeeping,
## and it self-heals if a tick somehow lands past 2 AM without touching 120.0 exactly.
static func should_force_passout(minutes: float, stay_awake: bool) -> bool:
	return not stay_awake \
		and minutes >= FORCED_PASSOUT_MINUTES \
		and minutes < float(DayManagerScript.DAY_START_MINUTES)


## Whether a tick crossed 6 AM from the late-night side while awake — the moment a stay-awake
## charge is spent (it bought THIS night; the next 2 AM must collapse the player again unless
## they drink another). Never true across a sleep transition: _end_day clears the flag anyway,
## and sleep jumps don't emit time_advanced, so this only ever sees lived-through time.
static func survived_night(prev_minutes: float, new_minutes: float) -> bool:
	return prev_minutes < float(DayManagerScript.DAY_START_MINUTES) \
		and new_minutes >= float(DayManagerScript.DAY_START_MINUTES)


func _play(action: String) -> void:
	var animation := "%s_%s" % [action, facing]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation) \
			and (sprite.animation != animation or not sprite.is_playing()):
		sprite.play(animation)


func _on_sprite_animation_finished() -> void:
	if using_tool:
		using_tool = false
		# Till-and-advance (see class doc / _process_step()): if a direction is still held
		# alongside "use_tool" when the swing finishes, queue a one-cell step in that direction
		# instead of immediately re-swinging in place — the next _physics_process tick will
		# fire another swing automatically once the step completes, chaining tile-by-tile for
		# as long as both are held.
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_pressed("use_tool") and input != Vector2.ZERO:
			var dir: Vector2 = FACING_VECTORS.get(facing, Vector2.ZERO)
			_step_target = global_position + dir * CELL_SIZE
			_stepping = true
		else:
			_play("idle")
