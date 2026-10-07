extends RefCounted
## Pure calendar maths (GDD.md §4, ROADMAP Phase 11): maps DayManager's absolute 1-based day
## counter onto 4 seasons of 28 days, years and weekdays. Static-only so every system (crops,
## weather, shops, NPC dialogue, HUD) asks the same questions the same way.

const DAYS_PER_SEASON := 28
const SEASONS_PER_YEAR := 4
const DAYS_PER_YEAR := DAYS_PER_SEASON * SEASONS_PER_YEAR
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {
	"spring": "Spring Rains",
	"summer": "Scorched Summer",
	"autumn": "Amber Autumn",
	"winter": "Grey Winter",
}
const SEASON_SHORT := {"spring": "Spring", "summer": "Summer", "autumn": "Autumn", "winter": "Winter"}
const WEEKDAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


static func season_index(day: int) -> int:
	return int((maxi(day, 1) - 1) / DAYS_PER_SEASON) % SEASONS_PER_YEAR


static func season(day: int) -> String:
	return SEASONS[season_index(day)]


static func day_of_season(day: int) -> int:
	return ((maxi(day, 1) - 1) % DAYS_PER_SEASON) + 1


static func year(day: int) -> int:
	return int((maxi(day, 1) - 1) / DAYS_PER_YEAR) + 1


static func weekday(day: int) -> String:
	return WEEKDAYS[(maxi(day, 1) - 1) % WEEKDAYS.size()]


static func is_first_day_of_season(day: int) -> bool:
	return day_of_season(day) == 1


static func date_text(day: int) -> String:
	return "%s %d" % [SEASON_SHORT[season(day)], day_of_season(day)]


static func long_date_text(day: int) -> String:
	return "%s, %s %d, Year %d" % [weekday(day), SEASON_NAMES[season(day)], day_of_season(day), year(day)]


## The absolute day number of `season_name`'s day `dom` in `year_number` (inverse of the above).
static func absolute_day(year_number: int, season_name: String, dom: int) -> int:
	var idx := maxi(SEASONS.find(season_name), 0)
	return (maxi(year_number, 1) - 1) * DAYS_PER_YEAR + idx * DAYS_PER_SEASON + clampi(dom, 1, DAYS_PER_SEASON)
