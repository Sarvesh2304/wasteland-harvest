extends SceneTree
## Balance probe (Milestone E): generates 40 ruins levels per depth with the real generator and
## reports containers, enemies and the expected sell value of searching everything (container
## tables via scripts/loot_db.gd's own data, tier per container).
## Run: godot --headless --path . --script res://tools/balance/ruins_value.gd

const RuinsGen := preload("res://scripts/ruins_gen.gd")
const ItemDB := preload("res://scripts/item_db.gd")

var _tables: Dictionary = {}


func _initialize() -> void:
	_tables = JSON.parse_string(FileAccess.get_file_as_string("res://data/loot_tables.json"))["tables"]
	print("depth  containers  enemies  loot_ev  enemy_ev")
	for depth in range(1, 5):
		var c := 0.0
		var e := 0.0
		var ev := 0.0
		var eev := 0.0
		var n := 40
		for s in n:
			var lvl: Dictionary = RuinsGen.generate(depth, 1000 + s * 31 + depth * 7919)
			c += lvl["containers"].size()
			e += lvl["enemies"].size()
			for cont in lvl["containers"]:
				ev += _search_value(String(cont["kind"]), int(cont.get("tier", depth)))
			for en in lvl["enemies"]:
				eev += _search_value(String(en["type"]), depth)
		print("%5d  %10.1f  %7.1f  %7.0f  %8.0f" % [depth, c / n, e / n, ev / n, eev / n])
	quit(0)


func _search_value(kind: String, tier: int) -> float:
	var table: Dictionary = _tables.get(kind, {})
	if table.is_empty():
		return 0.0
	var total := float(table.get("nothing", 0))
	var value := 0.0
	for entry in table["entries"]:
		if int(entry.get("min_tier", 1)) > tier or int(entry.get("max_tier", 9)) < tier:
			continue
		total += float(entry["weight"])
		value += float(entry["weight"]) * (float(entry["min"]) + float(entry["max"])) * 0.5 * ItemDB.sell_value(String(entry["item"]))
	if total <= 0.0:
		return 0.0
	var rolls: Dictionary = table.get("rolls", {"1": [1, 1]})
	var best := 1
	for key in rolls:
		if int(key) <= tier:
			best = maxi(best, int(key))
	var r: Array = rolls.get(str(best), [1, 1])
	return value / total * (float(r[0]) + float(r[1])) * 0.5
