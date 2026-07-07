extends CharacterBody2D
## The player character (ROADMAP Phase 2): 4-directional movement on a CharacterBody2D,
## with idle / walk / tool-use animations per facing direction.
##
## Collision: body on layer 2 ("player"), colliding against layer 1 ("world") — see
## project.godot [layer_names]. Energy is a Phase 3 system; Phase 2 carries the value and
## signal so the HUD's energy bar has something real to display (tool use costs a token
## amount purely to demonstrate the bar updating — judgment call, re-tune in Phase 3).

signal energy_changed(current: float, max_energy: float)

## ~3.5 tiles/second at the 16px tile size — close to Stardew's walk feel.
const SPEED := 56.0
const TOOL_USE_ENERGY_COST := 2.0

const FACINGS := ["south", "north", "east", "west"]

var facing := "south"
var max_energy := 100.0
var energy := max_energy
var using_tool := false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_play("idle")


func _physics_process(_delta: float) -> void:
	if using_tool:
		velocity = Vector2.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * SPEED
	move_and_slide()
	facing = facing_from_input(input, facing)
	_play("walk" if input != Vector2.ZERO else "idle")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_tool") and not using_tool:
		use_tool()


## Tool-use stub (Phase 2): plays the swing animation in the current facing and briefly locks
## movement. Phase 3 wires actual tool effects (tilling, watering, chopping) onto this.
func use_tool() -> void:
	using_tool = true
	velocity = Vector2.ZERO
	set_energy(energy - TOOL_USE_ENERGY_COST)
	_play("tool")


func set_energy(value: float) -> void:
	energy = clampf(value, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)


## Pure facing rule (testable headlessly): horizontal input wins on diagonals (Stardew-style
## side-facing bias), and facing is retained when input stops so idle keeps the last direction.
static func facing_from_input(input: Vector2, current: String) -> String:
	if input == Vector2.ZERO:
		return current
	if absf(input.x) >= absf(input.y) and input.x != 0.0:
		return "east" if input.x > 0.0 else "west"
	return "south" if input.y > 0.0 else "north"


func _play(action: String) -> void:
	var animation := "%s_%s" % [action, facing]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation) \
			and (sprite.animation != animation or not sprite.is_playing()):
		sprite.play(animation)


func _on_sprite_animation_finished() -> void:
	if using_tool:
		using_tool = false
		_play("idle")
