extends "res://tests/test_case.gd"
## scripts/weather.gd — per-season weather rolls and what each kind does.

const Weather := preload("res://scripts/weather.gd")
const Calendar := preload("res://scripts/calendar.gd")


func test_gentle_starts_are_always_clear() -> void:
	assert_eq(Weather.roll(1, "spring", 1, 0.0), Weather.CLEAR, "the first day of the game")
	assert_eq(Weather.roll(29, "summer", 1, 0.0), Weather.CLEAR, "the first day of a season")


func test_low_rolls_bring_the_season_weather() -> void:
	assert_eq(Weather.roll(5, "spring", 5, 0.0), Weather.RAIN)
	assert_eq(Weather.roll(90, "winter", 6, 0.0), Weather.SNOW)
	assert_eq(Weather.roll(5, "spring", 5, 0.999), Weather.CLEAR, "high rolls stay clear")


func test_every_roll_is_a_known_kind() -> void:
	for season in Calendar.SEASONS:
		for i in 100:
			var kind := Weather.roll(40, season, 12, float(i) / 100.0)
			assert_true(Weather.KINDS.has(kind), "%s roll %d gave %s" % [season, i, kind])


func test_clear_is_the_most_likely_weather_every_season() -> void:
	for season in Calendar.SEASONS:
		if season == "winter":
			continue  # winter is snowy by design
		var clear := 0
		for i in 1000:
			if Weather.roll(40, season, 12, float(i) / 1000.0) == Weather.CLEAR:
				clear += 1
		assert_true(clear >= 500, "%s is mostly clear (%d/1000)" % [season, clear])


func test_no_radstorms_before_day_20() -> void:
	for i in 1000:
		assert_ne(Weather.roll(19, "summer", 19, float(i) / 1000.0), Weather.RADSTORM)


func test_what_weather_does() -> void:
	assert_true(Weather.waters_crops(Weather.RAIN))
	assert_true(Weather.waters_crops(Weather.STORM))
	assert_true(Weather.waters_crops(Weather.RADSTORM), "radstorms still water inside the fence")
	assert_false(Weather.waters_crops(Weather.SNOW))
	assert_false(Weather.waters_crops(Weather.CLEAR))
	assert_true(Weather.is_wet(Weather.STORM))
	assert_false(Weather.is_wet(Weather.SNOW))
	assert_eq(Weather.display_name(Weather.RADSTORM), "Radstorm")
	assert_eq(Weather.display_name("nonsense"), "Clear")
