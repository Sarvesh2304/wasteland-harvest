extends RefCounted
## Fishing rules (data/fish.json, 2026-11-24 — docs/FISHING.md). Static module like
## festival_db.gd / market_rules.gd: lazy JSON load and pure functions — which fish can bite
## (water, season, time, weather), the weighted pick (junk, the legendary), bite timing, and the
## line-tension reel's physics step — so every rule is unit-testable without a scene. The live
## state (the cast, the bobber, the reel panel, the catch log) is scripts/fishing.gd.
##
## Not a `class_name` global (see scripts/item_db.gd's header) — callers must
## `const FishDB := preload("res://scripts/fish_db.gd")`.

const PATH := "res://data/fish.json"

const WATERS: Array[String] = ["pond", "river", "creek"]
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const TIMES: Array[String] = ["morning", "day", "evening", "night"]
const LEGENDARY_ID := "old_mayor"

## -- Casting --
const CHARGE_SECONDS := 1.0
const CAST_MIN_CELLS := 1
const CAST_MAX_CELLS := 4
const CAST_ENERGY := 2.0

## -- The bite --
const BITE_MIN := 1.5
const BITE_MAX := 6.0
const RAIN_BITE_MULT := 0.7
const DAWN_DUSK_BITE_MULT := 0.8
## Dawn 6-8 AM and dusk 6-8 PM, in minutes into the day.
const DAWN := Vector2(360.0, 480.0)
const DUSK := Vector2(1080.0, 1200.0)
const HOOK_WINDOW := 0.75
const MAX_NIBBLES := 2

## -- The reel (docs/FISHING.md §4) --
const REEL_UP := 0.9          # tension/s while Use is held
const REEL_DOWN := 0.7        # tension/s while it's released
const CATCH_START := 0.3
const START_TENSION := 0.3
const LOW_TENSION := 0.15     # below this the fish works loose
const SWEET_CENTER := 0.55
const WIDTH_EASY := 0.35      # difficulty 1
const WIDTH_HARD := 0.18      # difficulty 5
const WIDTH_PER_LEVEL := 0.01 # each Foraging level
const WIDTH_MAX := 0.45
const DRAIN := 0.22
const WARN_SECONDS := 0.45    # the fish tenses (shakes) this long before every run
const DRIFT := [0.0, 0.0, 0.04, 0.07, 0.1]
const DRIFT_SPEED := 0.8

## -- XP (Foraging) --
const JUNK_XP := 1

static var _data: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_data = parsed if parsed is Dictionary else {}


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()


## Test hook: use this data instead of the file (reload_from_disk() undoes it).
static func use_data(data: Dictionary) -> void:
	_loaded = true
	_data = data


static func data() -> Dictionary:
	_ensure_loaded()
	return _data


static func all_fish() -> Array:
	return data().get("fish", [])


static func ids() -> Array[String]:
	var out: Array[String] = []
	for f in all_fish():
		out.append(String((f as Dictionary).get("id", "")))
	return out


static func fish(id: String) -> Dictionary:
	for f in all_fish():
		if String((f as Dictionary).get("id", "")) == id:
			return f
	return {}


static func is_fish(id: String) -> bool:
	return not fish(id).is_empty()


static func display_name(id: String) -> String:
	return String(fish(id).get("name", id))


static func difficulty(id: String) -> int:
	return clampi(int(fish(id).get("difficulty", 1)), 1, 5)


static func is_legendary(id: String) -> bool:
	return bool(fish(id).get("legendary", false))


static func junk_list() -> Array:
	return data().get("junk", [])


static func junk_chance() -> float:
	return float(data().get("junk_chance", 0.1))


static func legendary_chance() -> float:
	return float(data().get("legendary_chance", 0.05))


## -- Eligibility --

## "morning" / "day" / "evening" / "night", or "" in the small hours (2-6 AM).
static func time_band(minutes: float) -> String:
	var m := fmod(minutes, 1440.0)
	var times: Dictionary = data().get("times", {})
	for band in TIMES:
		var span: Array = times.get(band, [])
		if span.size() < 2:
			continue
		var lo := float(span[0])
		var hi := float(span[1])
		if (m >= lo and m < hi) or (hi > 1440.0 and m + 1440.0 >= lo and m + 1440.0 < hi):
			return band
	return ""


static func is_rainy(weather: String) -> bool:
	return weather == "rain" or weather == "storm"


## Whether fish `f` can bite in `water`, `season`, time band `band` and `weather`.
static func can_bite(f: Dictionary, water: String, season: String, band: String, weather: String) -> bool:
	if water == "" or not (f.get("waters", []) as Array).has(water):
		return false
	if not (f.get("seasons", []) as Array).has(season):
		return false
	var times: Array = f.get("times", [])
	if not times.is_empty() and not times.has(band):
		return false
	if String(f.get("weather", "")) == "rain" and not is_rainy(weather):
		return false
	return true


## Every fish that could bite right now (the legendary included when its rules allow).
static func eligible(water: String, season: String, minutes: float, weather: String) -> Array[String]:
	var band := time_band(minutes)
	var out: Array[String] = []
	for f in all_fish():
		if can_bite(f, water, season, band, weather):
			out.append(String(f["id"]))
	return out


## Pick weight for a fish in `weather` (Bog Eel doubles in rain). The legendary has none: it's
## rolled separately.
static func weight(f: Dictionary, weather: String) -> float:
	if bool(f.get("legendary", false)):
		return 0.0
	var w := float(f.get("weight", 0))
	if is_rainy(weather):
		w *= float(f.get("rain_weight", 1.0))
	return w


## What bites: {"kind": "fish", "id": fish} or {"kind": "junk", "id", "item", "count", "line"};
## {} when nothing lives here. About one bite in ten is junk; the Old Mayor takes 5% of eligible
## bites until he's been caught once.
static func pick(water: String, season: String, minutes: float, weather: String,
		rng: RandomNumberGenerator, legendary_caught: bool = false) -> Dictionary:
	var pool := eligible(water, season, minutes, weather)
	if pool.is_empty():
		return {}
	if rng.randf() < junk_chance() and not junk_list().is_empty():
		var j: Dictionary = junk_list()[rng.randi_range(0, junk_list().size() - 1)]
		return {"kind": "junk", "id": String(j.get("id", "")), "item": String(j.get("item", "")),
			"count": int(j.get("count", 1)), "line": String(j.get("line", ""))}
	for id in pool:
		if is_legendary(id) and not legendary_caught and rng.randf() < legendary_chance():
			return {"kind": "fish", "id": id}
	var total := 0.0
	for id in pool:
		total += weight(fish(id), weather)
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	for id in pool:
		var w := weight(fish(id), weather)
		if w <= 0.0:
			continue
		roll -= w
		if roll <= 0.0:
			return {"kind": "fish", "id": id}
	for i in range(pool.size() - 1, -1, -1):
		if weight(fish(pool[i]), weather) > 0.0:
			return {"kind": "fish", "id": pool[i]}
	return {}


## Fish a request or Marta's demand list can ask for in `season`: catchable somewhere that
## season, whatever the weather, and common enough (weight 8+). Never the legendary.
static func request_pool(season: String) -> Array[String]:
	var out: Array[String] = []
	for f in all_fish():
		if bool(f.get("legendary", false)) or f.has("weather") or float(f.get("weight", 0)) < 8.0:
			continue
		if (f.get("seasons", []) as Array).has(season):
			out.append(String(f["id"]))
	return out


## -- Casting and the bite --

## Cells the bobber flies for a charge of `power` (0..1).
static func cast_cells(power: float) -> int:
	return clampi(CAST_MIN_CELLS + int(floor(clampf(power, 0.0, 1.0) * 4.0)), CAST_MIN_CELLS, CAST_MAX_CELLS)


## Seconds-to-bite multiplier: rain x0.7, dawn and dusk x0.8.
static func bite_multiplier(weather: String, minutes: float) -> float:
	var mult := 1.0
	if is_rainy(weather):
		mult *= RAIN_BITE_MULT
	var m := fmod(minutes, 1440.0)
	if (m >= DAWN.x and m < DAWN.y) or (m >= DUSK.x and m < DUSK.y):
		mult *= DAWN_DUSK_BITE_MULT
	return mult


## How long after the bobber lands the bite comes.
static func bite_delay(rng: RandomNumberGenerator, weather: String, minutes: float) -> float:
	return rng.randf_range(BITE_MIN, BITE_MAX) * bite_multiplier(weather, minutes)


## The nibbles before a bite (0-2 little twitches): times, ascending, all well before `bite_at`.
static func nibble_times(rng: RandomNumberGenerator, bite_at: float) -> Array[float]:
	var out: Array[float] = []
	var n := rng.randi_range(0, MAX_NIBBLES)
	if bite_at < 1.2:
		n = 0
	for i in n:
		out.append(rng.randf_range(0.4, bite_at - 0.6))
	out.sort()
	return out


## -- The reel --

## The sweet spot's width for a fish's difficulty and the player's Foraging level.
static func sweet_width(diff: int, foraging_level: int = 0) -> float:
	var d := clampi(diff, 1, 5)
	var base := lerpf(WIDTH_EASY, WIDTH_HARD, float(d - 1) / 4.0)
	return minf(base + WIDTH_PER_LEVEL * float(maxi(foraging_level, 0)), WIDTH_MAX)


## The fish's fight: how often it runs, how hard, how fast the catch bar fills.
static func reel_params(diff: int, foraging_level: int = 0) -> Dictionary:
	var d := clampi(diff, 1, 5)
	return {
		"difficulty": d,
		"width": sweet_width(d, foraging_level),
		"center": SWEET_CENTER,
		"drift": float(DRIFT[d - 1]),
		"force": 0.5 + 0.15 * float(d),
		"run_min": 0.45 + 0.08 * float(d),
		"run_max": 0.7 + 0.08 * float(d),
		"rest_min": 2.6 - 0.3 * float(d),
		"rest_max": 4.0 - 0.35 * float(d),
		"fill": 0.2 - 0.025 * float(d),
		"drain": DRAIN,
	}


## A fresh fight: tension and catch bar at their starting marks, the fish resting.
static func reel_start(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return {"tension": START_TENSION, "catch": CATCH_START, "phase": "rest",
		"timer": rng.randf_range(float(params["rest_min"]), float(params["rest_max"])),
		"t": 0.0, "result": ""}


## The sweet spot as [low, high] tension at fight time `t` (it drifts on hard fish).
static func sweet_spot(params: Dictionary, t: float) -> Vector2:
	var c := float(params["center"]) + float(params["drift"]) * sin(t * DRIFT_SPEED)
	var half := float(params["width"]) * 0.5
	return Vector2(c - half, c + half)


## One step of the fight: `holding` = Use held (reeling in). Returns a new state; its "result"
## becomes "snap" (tension hit 100%), "escape" (catch bar emptied) or "caught" (catch bar full).
static func reel_step(state: Dictionary, params: Dictionary, holding: bool, dt: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var s := state.duplicate()
	if String(s.get("result", "")) != "":
		return s
	var tension := float(s["tension"]) + (REEL_UP if holding else -REEL_DOWN) * dt
	if String(s["phase"]) == "run":
		tension += float(params["force"]) * dt
	tension = maxf(tension, 0.0)
	s["t"] = float(s["t"]) + dt
	if tension >= 1.0:
		s["tension"] = 1.0
		s["result"] = "snap"
		return s
	s["tension"] = tension
	var band := sweet_spot(params, float(s["t"]))
	var c := float(s["catch"])
	if tension >= band.x and tension <= band.y:
		c += float(params["fill"]) * dt
	elif tension < LOW_TENSION:
		c -= float(params["drain"]) * dt
	s["catch"] = clampf(c, 0.0, 1.0)
	if c <= 0.0:
		s["result"] = "escape"
		return s
	if c >= 1.0:
		s["result"] = "caught"
		return s
	s["timer"] = float(s["timer"]) - dt
	if float(s["timer"]) <= 0.0:
		match String(s["phase"]):
			"rest":
				s["phase"] = "warn"
				s["timer"] = WARN_SECONDS
			"warn":
				s["phase"] = "run"
				s["timer"] = rng.randf_range(float(params["run_min"]), float(params["run_max"]))
			_:
				s["phase"] = "rest"
				s["timer"] = rng.randf_range(float(params["rest_min"]), float(params["rest_max"]))
	return s


## -- Rewards and the log --

## Foraging XP for landing fish `id` (3 + 3 x difficulty); junk gives JUNK_XP.
static func catch_xp(id: String) -> int:
	return 3 + 3 * difficulty(id)


## The species caught at least once in `caught` ({id: count}).
static func species_caught(caught: Dictionary) -> int:
	var n := 0
	for id in caught:
		if int(caught[id]) > 0 and is_fish(String(id)):
			n += 1
	return n


## Dialogue flags for a catch log: has_fished (one fish ever), angler (6+ species),
## caught_old_mayor.
static func flags_for(caught: Dictionary, old_mayor: bool) -> Dictionary:
	var out := {}
	var total := 0
	for id in caught:
		total += int(caught[id])
	if total > 0:
		out["has_fished"] = true
	if species_caught(caught) >= 6:
		out["angler"] = true
	if old_mayor or int(caught.get(LEGENDARY_ID, 0)) > 0:
		out["caught_old_mayor"] = true
	return out


## Save shape: {"caught": {id: count}, "old_mayor": bool}. Unknown ids and junk counts drop out.
static func decode_log(data: Dictionary) -> Dictionary:
	var caught := {}
	var raw = data.get("caught", {})
	if raw is Dictionary:
		for id in raw:
			var n := int(raw[id])
			if n > 0 and is_fish(String(id)):
				caught[String(id)] = n
	return {"caught": caught, "old_mayor": bool(data.get("old_mayor", false)) or caught.has(LEGENDARY_ID)}


## -- Journal text --

const WATER_WORDS := {"pond": "the town pond", "river": "the river", "creek": "the creek"}
const TIME_WORDS := {"morning": "mornings", "day": "afternoons", "evening": "evenings", "night": "nights"}


## "Ponds and rivers. Spring, summer. Mornings, evenings. Only in rain." for the journal.
static func where_when(id: String) -> String:
	var f := fish(id)
	if f.is_empty():
		return ""
	var waters: Array[String] = []
	for w in f.get("waters", []):
		waters.append(String(WATER_WORDS.get(String(w), w)))
	var seasons: Array = f.get("seasons", [])
	var season_text := "All year" if seasons.size() >= 4 else ", ".join(seasons.map(func(s): return String(s).capitalize()))
	var times: Array = f.get("times", [])
	var time_text := "any time" if times.is_empty() else " and ".join(times.map(func(t): return String(TIME_WORDS.get(String(t), t))))
	var out := "In %s. %s, %s." % [_list_text(waters), season_text, time_text]
	if String(f.get("weather", "")) == "rain":
		out += " Only in the rain."
	elif float(f.get("rain_weight", 1.0)) > 1.0:
		out += " Bites more in the rain."
	return out


static func _list_text(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]
