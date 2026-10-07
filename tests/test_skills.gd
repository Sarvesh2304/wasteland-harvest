extends "res://tests/test_case.gd"
## scripts/skills.gd — the level curve, progress bar maths and tool energy discount.

const Skills := preload("res://scripts/skills.gd")


func test_level_curve() -> void:
	assert_eq(Skills.level_for_xp(0), 0)
	assert_eq(Skills.level_for_xp(99), 0)
	assert_eq(Skills.level_for_xp(100), 1, "100 XP is level 1")
	assert_eq(Skills.level_for_xp(379), 1)
	assert_eq(Skills.level_for_xp(380), 2)
	assert_eq(Skills.level_for_xp(15000), Skills.MAX_LEVEL)
	assert_eq(Skills.level_for_xp(999999), Skills.MAX_LEVEL, "capped at 10")


func test_progress_to_next_level() -> void:
	assert_eq(Skills.progress_to_next(0), 0.0)
	assert_eq(Skills.progress_to_next(50), 0.5, "halfway to level 1")
	assert_eq(Skills.progress_to_next(100), 0.0, "fresh into level 1")
	assert_eq(Skills.progress_to_next(240), 0.5, "halfway from 100 to 380")
	assert_eq(Skills.progress_to_next(20000), 1.0, "full at max level")


func test_energy_discount_by_level() -> void:
	assert_eq(Skills.energy_multiplier_for_level(0), 1.0)
	assert_true(absf(Skills.energy_multiplier_for_level(4) - 0.8) < 0.0001, "5% per level")
	assert_true(absf(Skills.energy_multiplier_for_level(10) - 0.5) < 0.0001, "half cost at 10")
	assert_true(absf(Skills.energy_multiplier_for_level(99) - 0.5) < 0.0001, "clamped")


func test_every_tool_maps_to_a_real_skill() -> void:
	for tool_kind in Skills.TOOL_SKILL:
		assert_true(Skills.SKILLS.has(Skills.TOOL_SKILL[tool_kind]), "%s maps to a skill" % tool_kind)
	for skill in Skills.SKILLS:
		assert_true(Skills.NAMES.has(skill) and Skills.PERK_TEXT.has(skill), "%s has a name and perk" % skill)
