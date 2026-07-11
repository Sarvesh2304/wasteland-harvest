extends Control
## Day-progress dial (playtest feedback, 2026-07-11 HUD redesign session): a small clock-face
## meter parked beside the day/clock plaque, showing how far the player is through the current
## in-game day. Fills clockwise from empty (6:00 AM, the day's start per DayManager) back to
## empty as DayManager.minutes_into_day advances, then snaps back to empty the instant a new day
## starts — day_progress_fraction() below is a plain wrap (fposmod), so it never needs its own
## "day changed" signal wiring; hud.gd just re-derives it from time_changed every tick like the
## rest of the clock display.
##
## Drawn procedurally via _draw() rather than as a new PixelLab plaque bitmap: a vector arc is
## exactly crisp at any control size (no nearest-neighbor integer-scale concerns at all, unlike
## the plaque textures or the pixel font — see art/ui/README.md), and reuses the HUD's already-
## established palette (GDD.md §9: scavenged metal ring, warm near-black backing, lamplight gold
## fill, the same gold as EnergyBar's fill and the plaque's cracked-glass highlights) so it reads
## as part of the same corner cluster rather than a new, unrelated visual language.

const RING_COLOR := Color("#9d9180")          # scavenged metal — GDD.md §9
const BACKING_COLOR := Color("#281a0b", 0.85) # warm near-black, matches plaque/label outlines
const FILL_COLOR := Color("#ffc948")          # lamplight gold — matches EnergyBar's fill

const RING_WIDTH := 3.0
const ARC_POINTS := 32

var _fraction := 0.0


## Called by hud.gd on every time_changed tick with day_progress_fraction()'s result.
func set_fraction(fraction: float) -> void:
	fraction = clampf(fraction, 0.0, 1.0)
	if is_equal_approx(fraction, _fraction):
		return
	_fraction = fraction
	queue_redraw()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5 - RING_WIDTH
	var center := size * 0.5
	# Backing disc first so the ring/fill read against a solid dark face, same as the plaque's
	# own dark cracked-glass window, rather than whatever's behind the HUD (grass, buildings...).
	draw_circle(center, radius + RING_WIDTH, BACKING_COLOR)
	draw_arc(center, radius, 0.0, TAU, ARC_POINTS, RING_COLOR, RING_WIDTH, false)
	if _fraction > 0.0:
		# 12 o'clock (straight up) is the day's start (6 AM); the fill sweeps clockwise as the
		# day progresses, same reading direction as a real clock's hour hand.
		var start := -PI / 2.0
		var end := start + TAU * _fraction
		var points: int = maxi(2, int(ARC_POINTS * _fraction) + 1)
		draw_arc(center, radius, start, end, points, FILL_COLOR, RING_WIDTH, false)
	# Small center hub, reading as the clock face's hand pivot.
	draw_circle(center, RING_WIDTH * 0.6, RING_COLOR)


## Pure fill-fraction math (headless-testable, see tests/test_day_dial.gd): how far through the
## current GAMEPLAY day minutes_into_day is, as 0..1 — relative to day_start_minutes (DayManager's
## DAY_START_MINUTES, 6:00 AM), not to literal midnight. This matters: DayManager's day counter
## and this HUD's "day" both conceptually run 6 AM to 6 AM (Stardew-style — see DayManager's own
## comments), but minutes_into_day itself is plain wall-clock minutes since midnight. Without the
## day_start_minutes offset, the dial would already read 25% full (360/1440) the instant a player
## wakes up, instead of empty — exactly backwards for a meter meant to show "how far into today
## you are." fposmod handles both the day-start wraparound and a value sitting exactly at (or
## past) minutes_per_day, so the dial always reads a clean 0 right as a new day begins.
static func day_progress_fraction(minutes_into_day: float, minutes_per_day: float,
		day_start_minutes: float = 0.0) -> float:
	if minutes_per_day <= 0.0:
		return 0.0
	return fposmod(minutes_into_day - day_start_minutes, minutes_per_day) / minutes_per_day
