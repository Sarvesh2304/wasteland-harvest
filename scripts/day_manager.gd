extends Node
## Global day/night clock (autoload "DayManager", ROADMAP Phase 2).
##
## Tracks in-game time at 1 in-game minute per real second (a full day = 24 real minutes) and
## the day counter. Emits signals the HUD listens to, and exposes a pure static sky-color
## gradient (dawn → noon → dusk → night) that main.tscn's CanvasModulate samples every frame.
## All time math and the gradient are static/pure so the headless test suite can exercise them
## without a running scene (see tests/test_day_manager.gd).

signal time_changed(day: int, minutes_into_day: float)
signal day_started(day: int)

## 1 in-game minute passes per real second (ROADMAP Phase 2's suggested rate).
const GAME_MINUTES_PER_REAL_SECOND := 1.0
const MINUTES_PER_DAY := 24 * 60
## Each day begins at 6:00 AM, Stardew-style. (Judgment call: the day *counter* still rolls
## over at midnight for Phase 2 simplicity; Stardew's 2 AM pass-out rule belongs to Phase 3's
## energy system.)
const DAY_START_MINUTES := 6 * 60

## Sky gradient keyframes: [hour (0-24), CanvasModulate color]. Piecewise-linearly
## interpolated, wrapping across midnight. Night is a cool moonlit blue; dawn and dusk pass
## through the game's dusty-amber identity (GDD.md §9); noon is pure white (art shows its
## true palette mid-day).
const SKY_KEYFRAMES: Array = [
	[0.0, Color(0.16, 0.17, 0.30)],   # deep night
	[5.0, Color(0.16, 0.17, 0.30)],   # last hour of night
	[6.5, Color(0.99, 0.76, 0.61)],   # dawn — warm amber wash
	[9.0, Color(1.0, 0.97, 0.92)],    # morning
	[12.0, Color(1.0, 1.0, 1.0)],     # noon — unmodulated
	[16.0, Color(1.0, 0.96, 0.88)],   # late afternoon
	[18.5, Color(0.95, 0.62, 0.45)],  # dusk — deep amber
	[20.5, Color(0.16, 0.17, 0.30)],  # nightfall complete
]

var day := 1
var minutes_into_day := float(DAY_START_MINUTES)
## Future pause hook (menus, cutscenes, sleep transitions).
var time_paused := false


func _process(delta: float) -> void:
	if time_paused:
		return
	advance_minutes(delta * GAME_MINUTES_PER_REAL_SECOND)


## Advance the clock by a number of in-game minutes, rolling the day counter over at midnight.
func advance_minutes(game_minutes: float) -> void:
	minutes_into_day += game_minutes
	while minutes_into_day >= MINUTES_PER_DAY:
		minutes_into_day -= MINUTES_PER_DAY
		day += 1
		day_started.emit(day)
	time_changed.emit(day, minutes_into_day)


## End-the-day-now transition: jumps straight to next morning rather than advancing
## minute-by-minute through the rest of the night. Two callers in player.gd: Phase 3's
## "pass out at zero energy" rule (_pass_out) and Phase 4 Stage 3's real bed/sleep interaction
## (_sleep_in_bed, which additionally auto-saves). Deliberately reuses day_started (rather than
## a separate signal) so every system that already reacts to a new day — crop growth and
## construction completion in particular — behaves identically whether the day changed by a
## natural midnight rollover, a collapse at 2 PM, or an early night in bed. The caller restores
## the player's energy to full itself (waking up rested is the whole point of the rule).
func skip_to_next_morning() -> void:
	day += 1
	minutes_into_day = float(DAY_START_MINUTES)
	day_started.emit(day)
	time_changed.emit(day, minutes_into_day)


func clock_text() -> String:
	return format_clock(minutes_into_day)


func current_sky_color() -> Color:
	return sky_color(minutes_into_day)


## "6:00 AM" / "12:07 PM" style 12-hour clock for the HUD.
static func format_clock(minutes: float) -> String:
	var total := int(floor(minutes))
	@warning_ignore("integer_division")
	var hour24 := (total / 60) % 24
	var minute := total % 60
	var suffix := "AM" if hour24 < 12 else "PM"
	var hour12 := hour24 % 12
	if hour12 == 0:
		hour12 = 12
	return "%d:%02d %s" % [hour12, minute, suffix]


## Pure gradient lookup: minutes into the day (0-1440) → CanvasModulate color.
static func sky_color(minutes: float) -> Color:
	var hour := fposmod(minutes, float(MINUTES_PER_DAY)) / 60.0
	var count: int = SKY_KEYFRAMES.size()
	for i in count:
		var a: Array = SKY_KEYFRAMES[i]
		var b: Array = SKY_KEYFRAMES[(i + 1) % count]
		var a_hour: float = a[0]
		var b_hour: float = b[0] if i + 1 < count else b[0] + 24.0  # wrap across midnight
		if hour >= a_hour and hour < b_hour:
			var t := (hour - a_hour) / (b_hour - a_hour)
			return (a[1] as Color).lerp(b[1] as Color, t)
	return SKY_KEYFRAMES[0][1]  # unreachable; keyframe 0 sits at hour 0.0
