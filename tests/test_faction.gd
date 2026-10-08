extends "res://tests/test_case.gd"
## scripts/faction.gd: the raider faction's standing bands, what moves reputation, and how
## close a non-hostile raider lets the player come.

const Faction := preload("res://scripts/faction.gd")


func test_standing_bands() -> void:
	assert_eq(Faction.standing(0), "Wary", "everyone starts wary")
	assert_eq(Faction.standing(-31), "Hostile")
	assert_eq(Faction.standing(-30), "Wary")
	assert_eq(Faction.standing(20), "Tolerated")
	assert_eq(Faction.standing(60), "Trusted")
	assert_true(Faction.attacks_on_sight(-50))
	assert_false(Faction.attacks_on_sight(0), "wary raiders warn before they shoot")


func test_actions_move_reputation_slowly_back() -> void:
	var rep := 0
	rep = Faction.after(rep, "kill")
	rep = Faction.after(rep, "kill")
	rep = Faction.after(rep, "kill")
	assert_eq(Faction.standing(rep), "Hostile", "three dead raiders and they shoot on sight")
	var runs := 0
	while Faction.attacks_on_sight(rep):
		rep = Faction.after(rep, "peaceful_run")
		runs += 1
	assert_true(runs >= 2, "recoverable, but it takes a while (%d peaceful runs)" % runs)
	assert_eq(Faction.after(99, "peaceful_run"), Faction.MAX_REP, "clamped at the top")
	assert_eq(Faction.after(-99, "kill"), Faction.MIN_REP, "clamped at the bottom")
	assert_eq(Faction.after(7, "nonsense"), 7)


func test_personal_space_by_standing() -> void:
	assert_eq(Faction.personal_space(0), Faction.WARY_PERSONAL_SPACE)
	assert_eq(Faction.personal_space(30), Faction.TOLERATED_PERSONAL_SPACE)
	assert_eq(Faction.personal_space(80), 0.0)
	assert_true(Faction.personal_space(-80) > 9999.0, "hostile raiders give no space at all")


func test_band_change_messages() -> void:
	assert_eq(Faction.change_message(0, -5), "", "no band crossed, no message")
	assert_true(Faction.change_message(0, -40).contains("shoot on sight"))
	assert_true(Faction.change_message(-40, -20).contains("Warily"))
	assert_true(Faction.change_message(10, 25).contains("tolerate"))
