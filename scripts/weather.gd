extends RefCounted
## Pure weather rules (ROADMAP Phase 11 / GDD.md §5): what kinds of weather exist, how likely
## each is per season, and what each one does. DayManager owns the actual today/tomorrow state
## and rolls it each morning; everything else reads it from there.
##
## Kinds: clear, rain (waters every tilled cell), storm (rain + lightning + wind), snow (winter's
## rain — waters nothing, crops don't grow outdoors in winter anyway), radstorm (green static sky;
## waters like rain inside the fence — the settlement stays a safe zone per the cozy contract —
## but makes the ruins far more dangerous; Milestone C).

const CLEAR := "clear"
const RAIN := "rain"
const STORM := "storm"
const SNOW := "snow"
const RADSTORM := "radstorm"

const KINDS: Array[String] = [CLEAR, RAIN, STORM, SNOW, RADSTORM]

const NAMES := {
	CLEAR: "Clear",
	RAIN: "Rain",
	STORM: "Storm",
	SNOW: "Snow",
	RADSTORM: "Radstorm",
}

## Cumulative-free probability tables per season; whatever is left over is clear.
const CHANCES := {
	"spring": {RAIN: 0.26, STORM: 0.05},
	"summer": {RAIN: 0.10, STORM: 0.10, RADSTORM: 0.04},
	"autumn": {RAIN: 0.18, STORM: 0.04, RADSTORM: 0.05},
	"winter": {SNOW: 0.40, RADSTORM: 0.03},
}


## Picks weather for an absolute day from one uniform roll in [0, 1). The first day of the game
## and the first day of every season are always clear (a gentle start, Stardew-style), and
## radstorms never happen in the first spring/summer of year 1 before day 20 (new players meet
## them once they've found their feet).
static func roll(day: int, season: String, day_of_season: int, roll_value: float) -> String:
	if day <= 1 or day_of_season == 1:
		return CLEAR
	var table: Dictionary = CHANCES.get(season, {})
	var acc := 0.0
	for kind in [RAIN, STORM, SNOW, RADSTORM]:
		if not table.has(kind):
			continue
		if kind == RADSTORM and day < 20:
			continue
		acc += float(table[kind])
		if roll_value < acc:
			return kind
	return CLEAR


## Whether this weather waters every tilled cell in the settlement at the start of the day.
static func waters_crops(kind: String) -> bool:
	return kind == RAIN or kind == STORM or kind == RADSTORM


static func is_wet(kind: String) -> bool:
	return kind == RAIN or kind == STORM or kind == RADSTORM


static func display_name(kind: String) -> String:
	return String(NAMES.get(kind, "Clear"))
