extends Node
## Global day/night clock (autoload "DayManager", ROADMAP Phase 2).
##
## Tracks in-game time (10 in-game minutes per 7 real seconds, Stardew's pace: a waking day from
## 6 AM to 2 AM lasts ~14 real minutes) and the day counter, plus calendar accessors (season,
## day-of-season, year) delegating to the pure scripts/calendar.gd. Emits signals the HUD listens to, and exposes a pure static sky-color
## gradient (dawn → noon → dusk → night) that main.tscn's CanvasModulate samples every frame.
## All time math and the gradient are static/pure so the headless test suite can exercise them
## without a running scene (see tests/test_day_manager.gd).

signal time_changed(day: int, minutes_into_day: float)
signal day_started(day: int)
## Lived-through clock movement ONLY (2026-07-11 forced-sleep rules): emitted by
## advance_minutes() — the path real frames drive — and never by skip_to_next_morning() or a
## direct minutes_into_day teleport (save-loads, test tooling). player.gd's night rules
## (post-midnight sleepy drain, the 2 AM forced pass-out) ride THIS signal, not time_changed,
## precisely because a sleep transition's backwards jump to 6 AM and a save-restore are not
## time the player spent awake: integrating them would drain phantom energy or re-trigger a
## pass-out mid-transition. prev/new can wrap midnight (new < prev) — advance_minutes only ever
## moves forward, so a receiver can trust any wrap is a genuine midnight crossing.
signal time_advanced(prev_minutes: float, new_minutes: float)

## 10 in-game minutes per 7 real seconds (2026-10-07: Stardew's proven pace, replacing Phase 2's
## 1 min/s — a 20-real-minute day dragged and diluted the "one more day" loop).
const GAME_MINUTES_PER_REAL_SECOND := 10.0 / 7.0
const MINUTES_PER_DAY := 24 * 60
## Each day begins at 6:00 AM, Stardew-style. (Judgment call: the day *counter* still rolls
## over at midnight for Phase 2 simplicity. Stardew's 2 AM pass-out rule, deferred since then,
## landed 2026-07-11 from direct playtest feedback — it lives in player.gd's forced-sleep
## rules, riding this clock's time_advanced signal; see player.gd's "night rules" section.)
const DAY_START_MINUTES := 6 * 60

const Calendar := preload("res://scripts/calendar.gd")
const Weather := preload("res://scripts/weather.gd")

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
## Pause hook, live since 2026-07-10: scripts/main.gd polls the modal gate every frame and sets
## this true while any modal UI (dialogue/store/shipping — deliberately not build mode, see
## main.gd's _process) is open, freezing the clock Stardew-style. Still available for future
## cutscenes/sleep transitions the same way.
var time_paused := false

## Today's and tomorrow's weather (scripts/weather.gd kinds). Rolled the moment a new day begins,
## BEFORE day_started fires, so every morning subscriber (crops, NPCs, HUD) sees today's weather.
## Tomorrow's is known a day ahead for the forecast. Saved/restored by main.gd.
var weather_today := Weather.CLEAR
var weather_tomorrow := Weather.CLEAR
## Seed for the deterministic per-day weather roll; set per save slot so two playthroughs differ
## but a reload reproduces the same forecast.
var weather_seed := 0
## Test/tooling override: when non-empty every roll returns this kind (e.g. "clear" so a smoke
## driver's crops only grow when it waters them). Never set by gameplay.
var forced_weather := ""


func _process(delta: float) -> void:
	if time_paused:
		return
	advance_minutes(delta * GAME_MINUTES_PER_REAL_SECOND)


## Advance the clock by a number of in-game minutes, rolling the day counter over at midnight.
func advance_minutes(game_minutes: float) -> void:
	var prev_minutes := minutes_into_day
	minutes_into_day += game_minutes
	while minutes_into_day >= MINUTES_PER_DAY:
		minutes_into_day -= MINUTES_PER_DAY
		day += 1
		_roll_weather_for_new_day()
		day_started.emit(day)
	time_changed.emit(day, minutes_into_day)
	# After time_changed on purpose: if a night-rules receiver ends the day (the 2 AM forced
	# pass-out calls skip_to_next_morning() synchronously from inside this emission), the HUD
	# has already seen this tick's honest clock value first, and skip's own time_changed then
	# reports the 6 AM wake-up as a second, later update.
	time_advanced.emit(prev_minutes, minutes_into_day)


## End-the-day-now transition: jumps straight to next morning rather than advancing
## minute-by-minute through the rest of the night. Three callers in player.gd: Phase 3's
## "pass out at zero energy" rule, the 2 AM forced pass-out (2026-07-11 forced-sleep rules),
## and Phase 4 Stage 3's real bed/sleep interaction — all via player._end_day(), which
## auto-saves. Deliberately reuses day_started (rather than a separate signal) so every system
## that already reacts to a new day — crop growth and construction completion in particular —
## behaves identically whether the day changed by a natural midnight rollover, a collapse at
## 2 PM, or an early night in bed. The caller restores the player's energy to full itself
## (waking up rested is the whole point of the rule).
##
## After-midnight fix (2026-07-11, landed with the forced-sleep rules that made this path hot):
## because the day counter already rolls — and day_started already fires — at the natural
## midnight rollover, ending a night AFTER midnight (a 1 AM bed sleep, the 2 AM forced
## pass-out, a late-night zero-energy collapse) must NOT increment the day or re-emit
## day_started: the player wakes at 6 AM of the calendar day that already started at midnight,
## and crops/construction/shipping must not tick a second time for the same night. Before this
## fix an after-midnight sleep silently skipped a whole day and double-advanced every
## day_started subscriber — latent since Phase 3 (reachable only by staying up past midnight,
## which nothing exercised), guaranteed-hot once the 2 AM rule made after-midnight endings the
## norm. The pure rule is morning_skip_adds_day() below.
func skip_to_next_morning() -> void:
	if morning_skip_adds_day(minutes_into_day):
		day += 1
		minutes_into_day = float(DAY_START_MINUTES)
		_roll_weather_for_new_day()
		day_started.emit(day)
		time_changed.emit(day, minutes_into_day)
		return
	minutes_into_day = float(DAY_START_MINUTES)
	time_changed.emit(day, minutes_into_day)


func clock_text() -> String:
	return format_clock(minutes_into_day)


## -- Calendar (delegates to scripts/calendar.gd) --

func season() -> String:
	return Calendar.season(day)


func day_of_season() -> int:
	return Calendar.day_of_season(day)


func year() -> int:
	return Calendar.year(day)


func date_text() -> String:
	return Calendar.date_text(day)


## -- Weather --

## Shifts tomorrow's forecast into today and rolls a new tomorrow. Deterministic per
## (weather_seed, day) so save/reload reproduces the same forecast.
func _roll_weather_for_new_day() -> void:
	weather_today = weather_tomorrow
	weather_tomorrow = roll_weather_for(day + 1)


func roll_weather_for(target_day: int) -> String:
	if forced_weather != "":
		return forced_weather
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([weather_seed, target_day])
	return Weather.roll(target_day, Calendar.season(target_day), Calendar.day_of_season(target_day),
		rng.randf())


## Fresh-game initialisation: day 1 is clear and tomorrow's forecast is rolled from the seed.
func reset_weather(seed_value: int) -> void:
	weather_seed = seed_value
	weather_today = forced_weather if forced_weather != "" else Weather.CLEAR
	weather_tomorrow = roll_weather_for(day + 1)


func is_raining() -> bool:
	return Weather.is_wet(weather_today)


func current_sky_color() -> Color:
	return sky_color(minutes_into_day)


## Pure rule for skip_to_next_morning() (headless-testable): a skip called at/after 6 AM ends a
## night whose midnight hasn't rolled yet, so the counter advances and day_started fires; a skip
## called between midnight and 6 AM (minutes 0..DAY_START, reachable only by staying up past
## midnight — the natural rollover already incremented the day and emitted day_started) just
## moves the clock forward to 6 AM of the already-started day. Exactly 6:00 AM counts as the
## former: minutes_into_day only ever sits at DAY_START_MINUTES right after waking, and a
## same-instant re-sleep should behave like any other daytime sleep.
static func morning_skip_adds_day(minutes: float) -> bool:
	return minutes >= float(DAY_START_MINUTES)


## The midnight-to-6-AM window (pure, wraps whole days for safety): true while the player is up
## past midnight. Drives player.gd's sleepy energy drain / 2 AM forced pass-out and hud.gd's
## pulsing "GETTING SLEEPY..." cue (2026-07-11 forced-sleep rules). This window is only
## reachable awake — every sleep/pass-out transition lands exactly AT 6 AM (DAY_START_MINUTES,
## excluded), and save files are only written at that same instant.
static func is_late_night(minutes: float) -> bool:
	return fposmod(minutes, float(MINUTES_PER_DAY)) < float(DAY_START_MINUTES)


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
