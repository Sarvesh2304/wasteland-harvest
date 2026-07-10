extends RefCounted
## Shared modal-UI mutual-exclusion registry (ROADMAP.md Phase 6: "All Year 1 systems integrated
## ... work together without conflicts").
##
## ## The bug this closes
## The game has grown four independent "take over the input" surfaces — build mode
## (scripts/builder.gd), the dialogue box (scripts/dialogue_ui.gd), Marta's store
## (scripts/store_ui.gd), and the shipping box's loading UI (scripts/shipping_ui.gd) — each with
## its own `active` flag, and none of them marks its input as handled
## (get_viewport().set_input_as_handled()), by long-standing convention (fabricated
## InputEventAction events in the test tooling are dispatched straight to each node's
## _unhandled_input, which a viewport-level handled mark wouldn't survive). That meant nothing
## stopped TWO of them being active at once: pressing "B" mid-conversation turned build mode on
## *under* the open dialogue box, after which a single "use_tool" press advanced the dialogue AND
## confirmed a blueprint placement simultaneously (and "move_up"/"move_down" double-drove both
## UIs' cycling). Player movement was never affected — player.gd's per-surface freeze checks all
## run before the build-mode check — but the double-driven input was real and reachable by any
## player who reflexively pressed B while talking.
##
## ## The mechanism
## One shared registry, created and wired by scripts/main.gd: every modal surface registers
## itself once, and refuses to OPEN while any *other* registered surface reports `active == true`.
## Closing is never gated — a surface must always be able to close itself, or a bug here could
## wedge the game shut. The gate reads each surface's existing `active` property by name (every
## current surface already exposes one, and player.gd already reads them the same way), so
## plugging in a future modal UI (quest journal, achievement popup, pause menu...) is three
## lines in main.gd's _ready():
##     modal_gate.register(new_ui)
##     new_ui.modal_gate = modal_gate
##     ...and the new UI's open path checks modal_gate.is_any_open_except(self).
##
## Note the direction of each guard: builder.gd gates set_active(true); the three open-by-signal
## UIs gate their open_*() entry points. The signal-opened UIs were already structurally
## unreachable while build mode is active (player.use_tool(), their only trigger, can't fire
## then — see player.gd's _physics_process guard), but the gate makes that invariant explicit
## and independent of player.gd's dispatch details rather than incidental to them.
##
## Deliberately a per-main-scene RefCounted owned by main.gd, NOT a third autoload: unlike
## DayManager/GameState it has no cross-scene job, and dying with the scene means a teardown/
## reload (see tools/runtime_smoke.gd stages 21/82) can never leak stale surface references into
## the next boot.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const ModalGate := preload("res://scripts/modal_gate.gd")`.

var _surfaces: Array = []


## Registers a modal surface (any Object exposing a boolean `active` property). Idempotent —
## re-registering the same surface is a no-op, so wiring code can't double-count one.
func register(surface: Object) -> void:
	if surface != null and not _surfaces.has(surface):
		_surfaces.append(surface)


func is_any_open() -> bool:
	return any_open(_surfaces)


## True if any registered surface OTHER than `exempt` is open — the check every surface makes
## before opening itself (its own `active` state must never veto its own toggle).
func is_any_open_except(exempt: Object) -> bool:
	return any_open(_surfaces, exempt)


## Pure core (headless-testable, no scene required): whether any surface in the list, other
## than `exempt`, reports `active == true`. Defensive on purpose: null entries, freed Objects,
## and objects with no `active` property all read as "not open" rather than erroring, so one
## badly-torn-down surface can't wedge every other UI shut.
static func any_open(surfaces: Array, exempt: Object = null) -> bool:
	for surface in surfaces:
		if surface == null or surface == exempt or not is_instance_valid(surface):
			continue
		if surface.get("active") == true:
			return true
	return false
