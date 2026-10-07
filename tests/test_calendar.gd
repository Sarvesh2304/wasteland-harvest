extends "res://tests/test_case.gd"
## scripts/calendar.gd — absolute day counter -> season / day-of-season / year / weekday.

const Calendar := preload("res://scripts/calendar.gd")


func test_first_day_is_spring_1_year_1() -> void:
	assert_eq(Calendar.season(1), "spring")
	assert_eq(Calendar.day_of_season(1), 1)
	assert_eq(Calendar.year(1), 1)
	assert_eq(Calendar.weekday(1), "Mon")
	assert_true(Calendar.is_first_day_of_season(1))


func test_season_boundaries() -> void:
	assert_eq(Calendar.season(28), "spring", "day 28 is the last of spring")
	assert_eq(Calendar.day_of_season(28), 28)
	assert_eq(Calendar.season(29), "summer", "day 29 opens summer")
	assert_eq(Calendar.day_of_season(29), 1)
	assert_true(Calendar.is_first_day_of_season(29))
	assert_eq(Calendar.season(57), "autumn")
	assert_eq(Calendar.season(85), "winter")
	assert_eq(Calendar.season(112), "winter", "day 112 closes year 1")


func test_years_wrap() -> void:
	assert_eq(Calendar.year(112), 1)
	assert_eq(Calendar.year(113), 2)
	assert_eq(Calendar.season(113), "spring", "year 2 starts in spring again")
	assert_eq(Calendar.day_of_season(113), 1)


func test_weekdays_cycle_every_seven_days() -> void:
	assert_eq(Calendar.weekday(7), "Sun")
	assert_eq(Calendar.weekday(8), "Mon")
	assert_eq(Calendar.weekday(29), "Mon", "28-day seasons keep weekdays aligned")


func test_bad_input_clamps_to_day_one() -> void:
	assert_eq(Calendar.season(0), "spring")
	assert_eq(Calendar.day_of_season(-5), 1)
	assert_eq(Calendar.year(0), 1)


func test_text_formats() -> void:
	assert_eq(Calendar.date_text(30), "Summer 2")
	assert_eq(Calendar.long_date_text(1), "Mon, Spring Rains 1, Year 1")


func test_absolute_day_inverts_the_lookups() -> void:
	for day in [1, 2, 28, 29, 56, 57, 100, 112, 113, 250]:
		var back := Calendar.absolute_day(Calendar.year(day), Calendar.season(day),
			Calendar.day_of_season(day))
		assert_eq(back, day, "day %d round-trips" % day)
