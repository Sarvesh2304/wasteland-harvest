extends CanvasModulate
## Drives the world-tint day/night cycle (ROADMAP Phase 2): every frame, samples the
## DayManager autoload's sky-color gradient (dawn → noon → dusk → night) and applies it as
## this CanvasModulate's color. The HUD lives on a CanvasLayer, so it is unaffected — only
## the world darkens at night, Stardew-style.


func _ready() -> void:
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	color = DayManager.current_sky_color()
