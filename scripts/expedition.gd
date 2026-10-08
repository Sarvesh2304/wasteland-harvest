extends Node
## The expedition loop (Milestone C, 2026-10-07; GDD.md §5). It plays out in six beats:
##   1. Ride out with Kael from his truck at the settlement's north checkpoint (the path zone).
##   2. Explore a generated ruins level: fight, loot, sneak, manage HP and radiation.
##   3. Optionally take the subway stairs deeper: harder, hotter, richer.
##   4. Head home at Kael's truck, which meets you on every level.
##   5. Turn the haul into settlement progress.
##   6. Dying out there, or collapsing at 2 AM, loses everything picked up on this expedition:
##      Kael drags you home and you wake the next morning at 10% HP.
##
## Built in code by main.gd, which hands it the ruins zone (map, objects, enemy director) and the
## shared pieces (player, fade, prompt, HUD, sound). The pure rules (the loot ledger, the death
## penalty, level names) are static and unit tested in tests/test_expedition.gd.

const Radiation := preload("res://scripts/radiation.gd")
const RuinsGen := preload("res://scripts/ruins_gen.gd")
const Faction := preload("res://scripts/faction.gd")
const ItemDB := preload("res://scripts/item_db.gd")

signal level_entered(depth: int, level_name: String)
signal ended(success: bool, summary: Dictionary)

## Clock cost of each leg (game minutes).
const DEPART_MINUTES := 30.0
const DESCEND_MINUTES := 10.0
const RETURN_MINUTES := 30.0
## HP you wake with after going down out there.
const DEATH_HP_FRACTION := 0.1
## Where Kael parks at home (the path zone), and where you stand when you get back.
const HOME_TRUCK_ZONE := "path"
const HOME_TRUCK_ANCHOR := Vector2i(10, 2)
const HOME_RETURN_CELL := Vector2i(11, 3)
## The district names by depth (deeper repeats the last), matching ruins_gen.gd's themes.
const DISTRICT_NAMES: Array[String] = ["Residential Blocks", "Downtown Ruins", "Industrial Quarter", "The Core"]
## Kael's one-time loan on the first ride out, if the player carries no weapon.
const FIRST_RIDE_GIFT := {"rusty_pipe": 1, "bandage": 3}

var active := false
var depth := 0
var level: Dictionary = {}
## Items picked up on this expedition (item_id -> count): what a death costs.
var ledger: Dictionary = {}
var kills := 0
## Saved progress: deepest level ever reached, expeditions run, Kael's loan given, notes read.
var max_depth := 0
var runs := 0
var gift_given := false
var notes_read: Array[String] = []
## The raider faction's view of the player (scripts/faction.gd), saved.
var raider_rep := 0
var _raider_blood := false

var main: Node = null
var player: Node = null
var ruins_map: Node2D = null
var ruins_objects: Node = null
var director: Node = null
var _seed := 0


func bind(main_node: Node, player_node: Node, map: Node2D, objects: Node, enemy_director: Node) -> void:
	main = main_node
	player = player_node
	ruins_map = map
	ruins_objects = objects
	director = enemy_director
	Events.item_gained.connect(_on_item_gained)
	DayManager.time_advanced.connect(_on_time_advanced)
	director.enemy_killed.connect(_on_enemy_killed)
	director.raider_provoked.connect(func() -> void:
		_raider_blood = true
		_shift_rep("provoke"))


## -- Pure rules (unit tested) --

static func district_name(level_depth: int) -> String:
	return DISTRICT_NAMES[clampi(level_depth - 1, 0, DISTRICT_NAMES.size() - 1)]


## Adds a pickup to the ledger.
static func record(book: Dictionary, item_id: String, count: int) -> void:
	if item_id == "" or count <= 0:
		return
	book[item_id] = int(book.get(item_id, 0)) + count


## What a death takes back: everything in the ledger still in the pack (ammo fired and medicine
## used are already gone; nothing brought from home is taken).
static func penalty(book: Dictionary, have: Dictionary) -> Dictionary:
	var out := {}
	for item_id in book:
		var n := mini(int(book[item_id]), int(have.get(item_id, 0)))
		if n > 0:
			out[item_id] = n
	return out


static func ledger_total(book: Dictionary) -> int:
	var n := 0
	for item_id in book:
		n += int(book[item_id])
	return n


## -- The flow --

## Called when the player has agreed to ride out (main.gd shows the prompt).
func depart() -> void:
	if active:
		return
	active = true
	depth = 0
	ledger.clear()
	kills = 0
	_raider_blood = false
	runs += 1
	_seed = hash([GameState.chosen_settlement_id, runs, DayManager.day])
	if not gift_given and not _has_weapon():
		gift_given = true
		for item_id in FIRST_RIDE_GIFT:
			player.inventory.add_item(item_id, int(FIRST_RIDE_GIFT[item_id]))
		Events.message.emit("Kael tossed you a pipe and some bandages. \"Bring them back.\"")
	DayManager.advance_minutes(DEPART_MINUTES)
	enter_level(1)


## Generates and enters level `level_depth` (the first, or the next one down the stairs).
func enter_level(level_depth: int) -> void:
	depth = level_depth
	max_depth = maxi(max_depth, depth)
	level = generate(depth, _seed + depth * 7919)
	director.raider_rep = raider_rep
	populate(level)
	main.enter_ruins(Vector2i(level.get("entry", Vector2i(2, 2))))
	player.ambient_rads = Radiation.ambient_rate(depth, DayManager.weather_today == "radstorm")
	level_entered.emit(depth, String(level.get("name", district_name(depth))))


func descend() -> void:
	if not active:
		return
	DayManager.advance_minutes(DESCEND_MINUTES)
	enter_level(depth + 1)


## Back home with the haul.
func extract() -> void:
	if not active:
		return
	var summary := _summary()
	if not _raider_blood:
		_shift_rep("peaceful_run")
	_finish()
	DayManager.advance_minutes(RETURN_MINUTES)
	main.leave_ruins(HOME_TRUCK_ZONE, HOME_RETURN_CELL)
	Audio.play_stinger("stinger_victory", -4.0)
	ended.emit(true, summary)


## Went down out there: the ledger is forfeit; wake at home next morning at 10% HP.
func fail() -> Dictionary:
	var lost := penalty(ledger, _inventory_counts())
	for item_id in lost:
		player.inventory.remove_item(String(item_id), int(lost[item_id]))
	var summary := _summary()
	summary["lost"] = lost
	_finish()
	ended.emit(false, summary)
	return summary


func _finish() -> void:
	active = false
	player.ambient_rads = 0.0
	director.clear()
	ruins_objects.clear_all()
	ruins_objects.clear_pickups()


func _summary() -> Dictionary:
	return {"depth": depth, "items": ledger_total(ledger), "kills": kills, "ledger": ledger.duplicate()}


## Kael won't wait forever: warnings at 11 PM and 1 AM (at 2 AM you collapse out there).
func _on_time_advanced(prev_minutes: float, new_minutes: float) -> void:
	if not active:
		return
	for warning in [[23.0 * 60.0, "It's getting late. Kael won't wait out here forever."],
			[60.0, "Kael leans on the horn. Get back to the truck, now."]]:
		var at: float = warning[0]
		if (prev_minutes < at and new_minutes >= at) or (new_minutes < prev_minutes and at < 120.0 and new_minutes >= at):
			Events.message.emit(String(warning[1]))
			Audio.play_sfx("alarm", -8.0)


func _on_enemy_killed(enemy_type: String) -> void:
	kills += 1
	if enemy_type == "raider":
		_raider_blood = true
		_shift_rep("kill")


func _shift_rep(event: String) -> void:
	var before := raider_rep
	raider_rep = Faction.after(raider_rep, event)
	director.raider_rep = raider_rep
	var msg := Faction.change_message(before, raider_rep)
	if msg != "":
		Events.message.emit(msg)


func _on_item_gained(item_id: String, count: int) -> void:
	if active:
		record(ledger, item_id, count)


func _has_weapon() -> bool:
	for slot in player.inventory.slots:
		if ItemDB.is_weapon(String((slot as Dictionary).get("item_id", ""))):
			return true
	return false


func _inventory_counts() -> Dictionary:
	var out := {}
	for slot in player.inventory.slots:
		var s: Dictionary = slot
		if s.is_empty():
			continue
		var id := String(s.get("item_id", ""))
		out[id] = int(out.get(id, 0)) + int(s.get("count", 1))
	return out


## -- Building a level --

## The level for `level_depth` from scripts/ruins_gen.gd; the hand-built yard below stands in
## only if the generator ever comes back empty.
static func generate(level_depth: int, seed_value: int) -> Dictionary:
	var out := RuinsGen.generate(level_depth, seed_value)
	if not (out.get("rows", []) as Array).is_empty():
		return out
	return fallback_level(level_depth)


## A walled yard with a street: the truck west, the stairs east, a few enemies and crates.
static func fallback_level(level_depth: int) -> Dictionary:
	var rows: Array[String] = []
	for y in 20:
		if y == 0 or y == 19:
			rows.append("F".repeat(36))
		elif y >= 8 and y <= 11:
			rows.append("F" + "a".repeat(34) + "F")
		elif y == 7 or y == 12:
			rows.append("F" + "c".repeat(34) + "F")
		else:
			rows.append("F" + ".".repeat(34) + "F")
	var enemies: Array = []
	var types := ["shambler", "shambler", "runner"] if level_depth < 2 else ["shambler", "runner", "bloater", "raider"]
	for i in 6 + level_depth * 2:
		enemies.append({"type": types[i % types.size()], "cell": Vector2i(14 + (i * 5) % 18, 3 + (i * 7) % 14), "group": -1})
	return {
		"depth": level_depth, "theme": "residential", "name": district_name(level_depth),
		"size": Vector2i(36, 20), "rows": rows,
		"entry": Vector2i(3, 11), "truck": Vector2i(2, 10), "stairs": Vector2i(32, 3),
		"buildings": [], "props": [{"kind": "car_wreck_1", "anchor": Vector2i(16, 9)}],
		"decor": [],
		"containers": [{"kind": "locker", "anchor": Vector2i(10, 3), "tier": 1},
			{"kind": "supply_crate", "anchor": Vector2i(24, 15), "tier": 1}],
		"breakables": [{"kind": "scrap_small", "anchor": Vector2i(8, 15)}],
		"enemies": enemies, "rad": [{"kind": "rad_barrel", "anchor": Vector2i(28, 16), "strength": 2.0}],
		"notes": [Vector2i(20, 4)],
	}


## Fills the ruins zone with `lvl`: terrain, objects, rad sources, decals, notes, enemies.
func populate(lvl: Dictionary) -> void:
	director.clear()
	ruins_objects.clear_all()
	ruins_objects.clear_pickups()
	ruins_map.load_ruins_level(lvl)
	ruins_objects.add_generated("kaels_truck", Vector2i(lvl.get("truck", Vector2i(1, 1))))
	ruins_objects.add_generated("subway_stairs", Vector2i(lvl.get("stairs", Vector2i(3, 3))))
	for b in lvl.get("buildings", []):
		ruins_objects.add_generated(String(b["kind"]), Vector2i(b["anchor"]))
	for p in lvl.get("props", []):
		ruins_objects.add_generated(String(p["kind"]), Vector2i(p["anchor"]))
	for c in lvl.get("containers", []):
		ruins_objects.add_generated(String(c["kind"]), Vector2i(c["anchor"]), int(c.get("tier", 1)))
	for b in lvl.get("breakables", []):
		ruins_objects.add_generated(String(b["kind"]), Vector2i(b["anchor"]))
	for r in lvl.get("rad", []):
		var anchor := Vector2i(r["anchor"])
		var strength := float(r.get("strength", 2.0))
		if String(r.get("kind", "")) == "rad_barrel":
			ruins_objects.add_generated("rad_barrel", anchor)
			director.add_rad_source(ruins_map.get_global_cell_center(anchor), strength, 28.0)
		else:
			# A 2x1 puddle: centred between its two cells.
			var center: Vector2 = ruins_map.get_global_cell_center(anchor) + Vector2(8, 0)
			director.add_rad_source(center, strength, 22.0, -1.0, true)
	for d in lvl.get("decor", []):
		director.add_decal(String(d["kind"]), ruins_map.get_global_cell_center(Vector2i(d["cell"])))
	for n in lvl.get("notes", []):
		ruins_objects.spawn_pickup("lore_note", 1, ruins_map.get_global_cell_center(Vector2i(n)))
	director.rebuild_nav()
	director.spawn_enemies(lvl.get("enemies", []), int(lvl.get("depth", 1)), _seed + int(lvl.get("depth", 1)))


## -- Save section "expedition" --

func save_state() -> Dictionary:
	return {"max_depth": max_depth, "runs": runs, "gift_given": gift_given, "notes_read": notes_read.duplicate(),
		"raider_rep": raider_rep}


func load_state(data: Dictionary) -> void:
	max_depth = int(data.get("max_depth", 0))
	runs = int(data.get("runs", 0))
	gift_given = bool(data.get("gift_given", false))
	raider_rep = Faction.clamp_rep(int(data.get("raider_rep", 0)))
	notes_read.clear()
	for id in data.get("notes_read", []):
		notes_read.append(String(id))
