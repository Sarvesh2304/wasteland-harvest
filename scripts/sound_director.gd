extends Node
## Chooses what plays (2026-10-07): the music track and ambience bed for the current zone, time
## of day, season and weather, plus the morning bell. A child of Main; main.gd tells it which
## zone the player is in, everything else it reads from DayManager.
##
## Rules (Stardew's restraint: music is welcome, never constant):
## - Daytime outdoors: the season's theme (farm/path/ranch) or the town theme (town).
## - Evening (after 6:30 PM): the night theme; after midnight: ambience only.
## - Rain/storm/radstorm: no music — the weather is the soundtrack.
## - Ambience follows zone + time + weather (birds by day, crickets at night, rain, wind...).

const Weather := preload("res://scripts/weather.gd")

const EVENING_MINUTES := 18 * 60 + 30
const SILENT_AFTER_MIDNIGHT := true

var zone_id := "farm"
## Set by modal UIs that want their own music (e.g. the shop) — "" = normal rules.
var override_track := ""
var _last_hour := -1


func _ready() -> void:
	DayManager.time_changed.connect(_on_time_changed)
	DayManager.day_started.connect(_on_day_started)


func set_zone(id: String) -> void:
	zone_id = id
	refresh()


func set_override(track: String) -> void:
	override_track = track
	refresh()


func _on_time_changed(_day: int, minutes: float) -> void:
	var hour := int(minutes / 30.0)
	if hour != _last_hour:
		_last_hour = hour
		refresh()


func _on_day_started(_day: int) -> void:
	Audio.play_sfx("day_start", -4.0, 0.0)
	refresh()


func refresh() -> void:
	Audio.play_music(music_for(zone_id, DayManager.minutes_into_day, DayManager.season(),
		DayManager.weather_today, override_track))
	Audio.play_ambience(ambience_for(zone_id, DayManager.minutes_into_day, DayManager.season(),
		DayManager.weather_today))


## Pure: which music track should play ("" = none).
static func music_for(zone: String, minutes: float, season: String, weather: String,
		override: String = "") -> String:
	if override != "":
		return override
	# The ruins keep their own soundscape at any hour, in any weather.
	if zone == "ruins_deep":
		return "ruins_deep"
	if zone.begins_with("ruins"):
		return "ruins_explore"
	if Weather.is_wet(weather):
		return ""
	var late := minutes < 6 * 60  # after midnight
	if late and SILENT_AFTER_MIDNIGHT:
		return ""
	if minutes >= EVENING_MINUTES:
		return "night"
	if zone == "town":
		return "town"
	return season


## Pure: which ambience loop should play ("" = none).
static func ambience_for(zone: String, minutes: float, season: String, weather: String) -> String:
	if zone.begins_with("ruins"):
		return "amb_radstorm" if weather == Weather.RADSTORM else "amb_ruins"
	match weather:
		Weather.STORM:
			return "amb_storm"
		Weather.RAIN:
			return "amb_rain"
		Weather.RADSTORM:
			return "amb_radstorm"
	var night := minutes >= 20 * 60 or minutes < 6 * 60
	if season == "winter":
		return "amb_wind"
	if night:
		return "amb_farm_night"
	if zone == "town":
		return "amb_town"
	return "amb_farm_day"
