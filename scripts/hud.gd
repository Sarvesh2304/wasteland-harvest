extends CanvasLayer
## Basic HUD (ROADMAP Phase 2): day number, in-game clock, energy bar.
##
## Lives on a CanvasLayer so the day/night CanvasModulate in main.tscn never darkens it.
## Listens to the DayManager autoload for time, and to the player's energy_changed signal
## (bound by main.gd) for the energy bar. Art: PixelLab-generated scavenged-metal panel and
## bar frame (art/ui/), with the bar fill drawn as flat palette colors (lamplight gold
## #e8c268 on warm near-black) so the readout stays legible at the 320x192 viewport.

@onready var day_label: Label = %DayLabel
@onready var clock_label: Label = %ClockLabel
@onready var energy_fill: ProgressBar = %EnergyFill


func _ready() -> void:
	DayManager.time_changed.connect(_on_time_changed)
	_on_time_changed(DayManager.day, DayManager.minutes_into_day)


## Called by main.gd once the player exists.
func bind_player(player: Node) -> void:
	player.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(player.energy, player.max_energy)


func _on_time_changed(day: int, minutes_into_day: float) -> void:
	# time_changed fires every frame; only touch the labels when the visible text changes.
	var day_text := "Day %d" % day
	if day_label.text != day_text:
		day_label.text = day_text
	var clock := DayManager.format_clock(minutes_into_day)
	if clock_label.text != clock:
		clock_label.text = clock


func _on_energy_changed(current: float, max_energy: float) -> void:
	energy_fill.max_value = max_energy
	energy_fill.value = current
