extends "res://tests/test_case.gd"
## scripts/sound_director.gd — the pure music/ambience selection rules.

const SoundDirector := preload("res://scripts/sound_director.gd")

const NOON := 12.0 * 60.0
const EVENING := 19.0 * 60.0
const LATE := 1.0 * 60.0


func test_daytime_music_follows_the_season_and_zone() -> void:
	assert_eq(SoundDirector.music_for("farm", NOON, "spring", "clear"), "spring")
	assert_eq(SoundDirector.music_for("ranch", NOON, "autumn", "clear"), "autumn")
	assert_eq(SoundDirector.music_for("town", NOON, "summer", "clear"), "town")
	assert_eq(SoundDirector.music_for("ruins_1", NOON, "summer", "clear"), "ruins_explore")


func test_evening_and_after_midnight() -> void:
	assert_eq(SoundDirector.music_for("farm", EVENING, "spring", "clear"), "night")
	assert_eq(SoundDirector.music_for("farm", LATE, "spring", "clear"), "", "silence after midnight")


func test_wet_weather_mutes_music() -> void:
	assert_eq(SoundDirector.music_for("farm", NOON, "spring", "rain"), "")
	assert_eq(SoundDirector.music_for("town", NOON, "summer", "storm"), "")


func test_override_wins() -> void:
	assert_eq(SoundDirector.music_for("farm", NOON, "spring", "rain", "shop"), "shop")


func test_ambience_rules() -> void:
	assert_eq(SoundDirector.ambience_for("farm", NOON, "spring", "clear"), "amb_farm_day")
	assert_eq(SoundDirector.ambience_for("farm", 22.0 * 60.0, "spring", "clear"), "amb_farm_night")
	assert_eq(SoundDirector.ambience_for("town", NOON, "spring", "clear"), "amb_town")
	assert_eq(SoundDirector.ambience_for("farm", NOON, "spring", "rain"), "amb_rain")
	assert_eq(SoundDirector.ambience_for("farm", NOON, "summer", "storm"), "amb_storm")
	assert_eq(SoundDirector.ambience_for("farm", NOON, "winter", "clear"), "amb_wind")
	assert_eq(SoundDirector.ambience_for("ruins_1", NOON, "spring", "clear"), "amb_ruins")
	assert_eq(SoundDirector.ambience_for("ruins_1", NOON, "summer", "radstorm"), "amb_radstorm")
