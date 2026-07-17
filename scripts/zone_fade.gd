extends CanvasLayer
## The zone-transition fade (the Farm/Path/Town/Ranch zone split): a full-screen black overlay
## on its own CanvasLayer, layered ABOVE the HUD (a transition that left the HUD visible over a
## black world would look broken, not polished), starting fully transparent.
##
## play(midpoint) runs the whole ~0.15s beat: fade to black over FADE_HALF_SECONDS, call
## `midpoint` while fully black (main.gd passes its _bind_zone teleport/rebind — invisible to
## the player, hidden inside the black frame exactly like an instant cut, just softened), then
## fade back in. The camera itself is untouched — game_camera.gd's set_target(player, snap)
## does the actual repositioning inside the midpoint, per the plan's Fixed Decision 3.
##
## Re-entrancy: `playing` refuses overlapping play() calls so a stray second request can never
## corrupt the running tween. In practice player.gd's _zone_transitioning guard already ensures
## exactly one zone_exit_requested per crossing (the fade's 0.15s window leaves the player
## standing on the gate cell, which would otherwise re-detect every physics frame — see
## player.gd's _physics_process); this refusal is belt-and-suspenders, and play_count exists so
## tools/zone_transition_smoke.gd can assert the single-fire behaviour directly.

const FADE_HALF_SECONDS := 0.075

## True while a fade is in flight. Exposed (with play_count) for the smoke tooling.
var playing := false
## Total accepted play() calls this session.
var play_count := 0
## play() calls refused because a fade was already in flight — should stay 0 in a correct
## session; the held-key regression stage in tools/zone_transition_smoke.gd asserts on it.
var rejected_count := 0

var _rect: ColorRect


func _ready() -> void:
	# Above the HUD (scenes/hud.tscn's CanvasLayer sits at the default layer 1).
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


## Fade out, run `midpoint` while black, fade back in. See the class doc.
func play(midpoint: Callable) -> void:
	if playing:
		rejected_count += 1
		return
	playing = true
	play_count += 1
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", 1.0, FADE_HALF_SECONDS)
	tween.tween_callback(midpoint)
	tween.tween_property(_rect, "color:a", 0.0, FADE_HALF_SECONDS)
	tween.tween_callback(func() -> void: playing = false)
