extends RefCounted
## Notice-board requests (data/requests.json) and Town Works projects (data/projects.json),
## Milestone B 2026-10-08 — docs/SOCIAL_AND_QUESTS.md §5-6. Static module: lazy JSON load and pure
## rules (picking today's request, its reward and wording, what a contribution takes). The live
## state is scripts/quests.gd.

const REQUESTS_PATH := "res://data/requests.json"
const PROJECTS_PATH := "res://data/projects.json"
const ItemDB := preload("res://scripts/item_db.gd")
const CropDB := preload("res://scripts/crop_db.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const Calendar := preload("res://scripts/calendar.gd")
const EnemyDB := preload("res://scripts/enemy_db.gd")

## A request is due this many days after it's accepted (Stardew's two).
const DUE_DAYS := 2
## Deliveries pay this many times the items' sell value, never less than MIN_REWARD.
const REWARD_MULTIPLIER := 3
const MIN_REWARD := 30
const HUNT_REWARD_PER_KILL := 35
## How long a Town Works project keeps its "_new" dialogue flag after it's finished.
const NEW_PROJECT_DAYS := 3

const POOLS := {
	"material": ["wood", "stone", "fiber", "hardwood"],
	"salvage": ["copper_wire", "plastic", "rubber", "cloth_scrap", "glass", "battery", "scrap_metal"],
	"cooked": ["cooked_meal", "potato_hash", "pepper_chili", "pumpkin_soup", "corn_bread"],
	"artisan": ["berry_jam", "pickled_veg", "cheese", "honey", "glow_wine", "charcoal", "metal_bar"],
}
const HUNT_ENEMIES: Array[String] = ["shambler", "runner", "bloater", "rad_hound"]
const WEEKDAY_NAMES := {"Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday",
	"Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday"}
## Mass nouns: counted but never pluralised ("10 Wood", "3 Copper Wire", "6 Dustwheat"). Everything
## else takes a plural ("3 Batteries", "2 Circuit Boards", "5 Mutant Potatoes").
const MASS_NOUNS: Array[String] = [
	"wood", "hardwood", "stone", "scrap_metal", "fiber", "charcoal", "copper_wire", "glass", "plastic",
	"rubber", "cloth_scrap", "tree_sap", "chemicals", "gunpowder", "lead_scrap", "fertilizer",
	"quality_fertilizer", "dustwheat_grain", "dust_corn", "cleanleaf_kale", "honey", "cheese", "milk",
	"mutant_goat_milk", "rotgut", "glow_wine", "berry_jam", "potato_hash", "pepper_chili", "pumpkin_soup",
	"corn_bread", "crystal_moss", "frost_lichen", "mystery_jerky", "coffee", "purified_water",
]

static var _templates: Array = []
static var _projects: Array = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_templates = _read(REQUESTS_PATH).get("templates", [])
	_projects = _read(PROJECTS_PATH).get("projects", [])


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()


## Test hook: use these templates/projects instead of the files (reload_from_disk() undoes it).
static func use_data(template_list: Array, project_list: Array) -> void:
	_loaded = true
	_templates = template_list
	_projects = project_list


## -- Requests --

static func templates() -> Array:
	_ensure_loaded()
	return _templates


static func template(id: String) -> Dictionary:
	for t in templates():
		if String((t as Dictionary).get("id", "")) == id:
			return t
	return {}


## The items a pool can ask for in `season` (crops and forage follow the season).
static func pool_items(pool: String, season: String) -> Array[String]:
	var out: Array[String] = []
	match pool:
		"crop":
			for crop_id in CropDB.crops_for_season(season):
				var item := String(CropDB.get_crop(crop_id).get("yield_item", crop_id))
				if ItemDB.has_item(item) and not out.has(item):
					out.append(item)
		"forage":
			for kind in WorldObjectDB.kinds_spawning_on("forage_" + season):
				var item := WorldObjectDB.forage_item(kind)
				if ItemDB.has_item(item) and not out.has(item):
					out.append(item)
		_:
			for item in POOLS.get(pool, []):
				if ItemDB.has_item(String(item)):
					out.append(String(item))
	return out


## Whether template `t` can be posted on `day` in `season` after `runs` expeditions, with `depth` the
## deepest district reached (a hunt for things that only live deeper waits for "min_depth").
static func eligible(t: Dictionary, day: int, season: String, runs: int, depth: int = 99) -> bool:
	if day < int(t.get("min_day", 1)) or runs < int(t.get("min_runs", 0)):
		return false
	if depth < int(t.get("min_depth", 0)):
		return false
	if t.has("season") and String(t["season"]) != season:
		return false
	if String(t.get("kind", "")) == "deliver":
		return not _choices_for(t, season).is_empty()
	return String(t.get("kind", "")) == "hunt"


static func _choices_for(t: Dictionary, season: String) -> Array[String]:
	var out: Array[String] = []
	if t.has("items"):
		for item in t["items"]:
			if ItemDB.has_item(String(item)):
				out.append(String(item))
		return out
	return pool_items(String(t.get("pool", "")), season)


## Today's request: an eligible template (not from `skip_npc`, so the same face doesn't post twice
## running when there's a choice), an item from its pool and a count. {} when nothing is eligible.
## Deterministic for a given rng state.
static func generate(day: int, season: String, runs: int, rng: RandomNumberGenerator,
		skip_npc: String = "", depth: int = 99) -> Dictionary:
	var pool: Array = templates().filter(func(t): return eligible(t, day, season, runs, depth))
	var fresh: Array = pool.filter(func(t): return String(t.get("npc", "")) != skip_npc)
	if not fresh.is_empty():
		pool = fresh
	if pool.is_empty():
		return {}
	var t: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var span: Array = t.get("count", [1, 1])
	var count := rng.randi_range(int(span[0]), int(span[span.size() - 1]))
	var req := {"template": String(t["id"]), "npc": String(t.get("npc", "")),
		"kind": String(t.get("kind", "deliver")), "count": count, "posted_day": day}
	if req["kind"] == "hunt":
		var enemy := String(t.get("enemy", "any"))
		req["enemy"] = enemy
		req["reward"] = HUNT_REWARD_PER_KILL * count
	else:
		var choices := _choices_for(t, season)
		var item := choices[rng.randi_range(0, choices.size() - 1)]
		req["item"] = item
		req["reward"] = delivery_reward(item, count)
	return req


static func delivery_reward(item_id: String, count: int) -> int:
	var raw := REWARD_MULTIPLIER * ItemDB.sell_value(item_id) * count
	return maxi(MIN_REWARD, int(round(raw / 5.0)) * 5)


## "5 Mutant Potatoes", "10 Wood", "1 Glow Melon".
static func amount_text(item_id: String, count: int) -> String:
	var name := ItemDB.display_name(item_id)
	if count == 1 or MASS_NOUNS.has(item_id):
		return "%d %s" % [count, name]
	return "%d %s" % [count, plural(name)]


## Plain English plurals for item names (the last word changes): Potato -> Potatoes,
## Berry -> Berries, Radish -> Radishes; names already ending in s stay put (Rustvine Grapes).
static func plural(name: String) -> String:
	if name.ends_with("s"):
		return name
	if name.ends_with("sh") or name.ends_with("ch") or name.ends_with("x") or name.ends_with("o"):
		return name + "es"
	if name.ends_with("y") and name.length() > 1 and not "aeiou".contains(name[name.length() - 2]):
		return name.substr(0, name.length() - 1) + "ies"
	return name + "s"


static func enemy_name(enemy: String, count: int) -> String:
	if enemy == "any" or enemy == "":
		return "creature" if count == 1 else "creatures"
	var name := String(EnemyDB.get_enemy(enemy).get("name", enemy.capitalize())).to_lower()
	return name if count == 1 else plural(name)


## The request's board text, or the template's thanks line, with its tokens filled.
static func text_for(req: Dictionary, field: String, due_day: int = -1) -> String:
	var t := template(String(req.get("template", "")))
	var count := int(req.get("count", 1))
	var item := ""
	if String(req.get("kind", "")) == "hunt":
		item = enemy_name(String(req.get("enemy", "any")), count)
	else:
		item = amount_text(String(req.get("item", "")), count)
		# {count} {item} in a template reads "5 5 Mutant Potatoes" unless {item} is the bare name.
		item = item.substr(item.find(" ") + 1)
	var due := ""
	if due_day > 0:
		due = String(WEEKDAY_NAMES.get(Calendar.weekday(due_day), Calendar.weekday(due_day)))
	return DialogueDB.fill(String(t.get(field, "")), {"count": count, "item": item, "due": due,
		"npc": DialogueDB.display_name(String(req.get("npc", "")))})


static func title_of(req: Dictionary) -> String:
	return String(template(String(req.get("template", ""))).get("title", "Request"))


## -- Town Works projects --

static func projects() -> Array:
	_ensure_loaded()
	return _projects


static func project(id: String) -> Dictionary:
	for p in projects():
		if String((p as Dictionary).get("id", "")) == id:
			return p
	return {}


static func project_ids() -> Array[String]:
	var out: Array[String] = []
	for p in projects():
		out.append(String((p as Dictionary).get("id", "")))
	return out


static func needs(id: String) -> Dictionary:
	var out := {}
	var raw: Dictionary = project(id).get("needs", {})
	for item in raw:
		out[String(item)] = int(raw[item])
	return out


static func credits_needed(id: String) -> int:
	return int(project(id).get("credits", 0))


## What's still owed: {item: count} for unfinished items, plus "credits" if any Credits are owed.
## `given` is what's been contributed so far ({item: count, "credits": n}).
static func remaining(id: String, given: Dictionary) -> Dictionary:
	var out := {}
	var need := needs(id)
	for item in need:
		var left := int(need[item]) - int(given.get(item, 0))
		if left > 0:
			out[item] = left
	var credits_left := credits_needed(id) - int(given.get("credits", 0))
	if credits_left > 0:
		out["credits"] = credits_left
	return out


static func is_funded(id: String, given: Dictionary) -> bool:
	return not project(id).is_empty() and remaining(id, given).is_empty()


## What a contribution takes given what the player carries (`have`: {item: count}) and their
## Credits: as much of each still-owed item as they have, and Credits up to what's owed.
## {item: count, "credits": n}; empty when they have nothing that helps.
static func contribution(id: String, given: Dictionary, have: Dictionary, credits: int) -> Dictionary:
	var out := {}
	var left := remaining(id, given)
	for item in left:
		if item == "credits":
			continue
		var take := mini(int(left[item]), int(have.get(item, 0)))
		if take > 0:
			out[item] = take
	var credits_take := mini(int(left.get("credits", 0)), maxi(credits, 0))
	if credits_take > 0:
		out["credits"] = credits_take
	return out


## 0..1 progress toward a project (items and Credits weighted by value, so 300 Cr isn't one unit).
static func progress(id: String, given: Dictionary) -> float:
	var total := float(credits_needed(id))
	var done := float(mini(int(given.get("credits", 0)), credits_needed(id)))
	var need := needs(id)
	for item in need:
		var unit := float(maxi(ItemDB.sell_value(item), 1))
		total += unit * float(need[item])
		done += unit * float(mini(int(given.get(item, 0)), int(need[item])))
	return 1.0 if total <= 0.0 else clampf(done / total, 0.0, 1.0)
