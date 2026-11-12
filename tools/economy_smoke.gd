extends SceneTree
## Milestone D economy smoke (2026-11-11, docs/LIVING_SETTLEMENT.md §1-3): boots the real game
## (Forest Edge) and drives the market, the caravan and the trading post end to end.
##   1. A big shipment sells at list price, floods the shelf, and the next one pays less; the
##      shipping screen shows the falling price.
##   2. Tully is at the market stall on Wednesday (day 3) and gone on Thursday; his stall is the
##      store screen with his prices and limited stock, and buying counts the stock down.
##   3. Hearts with Tully take 2% each off his prices.
##   4. The second Monday posts a demand list; an item on it ships at +40%.
##   5. A trading post is built, stocked through its real shelf screen, its markup cycled with Q,
##      and sells overnight at that markup, in shelf order, up to the day's trade.
##   6. Save and reload: the flood, the demand list, the stall's stock and the post's shelf and
##      markup all survive.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/economy_smoke.gd

const ItemDB := preload("res://scripts/item_db.gd")
const CaravanScript := preload("res://scripts/caravan.gd")
const MarketRules := preload("res://scripts/market_rules.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")

const POST_CELL := Vector2i(30, 12)

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var failures: Array[String] = []
var stage := 0
var ticks := 0
var _finished := false
var _credits := 0
var _flood_mult := 1.0
var _demand: Array = []
var _stall: Array = []


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://economy_smoke_saves"
	game_state.legacy_save_path = "user://economy_smoke_saves/legacy.json"
	game_state.save_path = "user://economy_smoke_saves/slot_1.json"
	_wipe()
	game_state.chosen_settlement_id = "forest_edge"
	_boot()


func _boot() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _wipe() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("economy_smoke_saves"):
		for f in DirAccess.get_files_at("user://economy_smoke_saves"):
			DirAccess.remove_absolute("user://economy_smoke_saves/" + f)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("stage %d: %s" % [stage, message])


func _next(to_stage: int) -> void:
	stage = to_stage
	ticks = 0


func _press(ui: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui._unhandled_input(event)


func _next_morning() -> void:
	day_manager.skip_to_next_morning()
	day_manager.minutes_into_day = 9 * 60.0
	if main.confirm_ui.active:
		main.confirm_ui.choose(0)


func _go_to_day(day: int) -> void:
	while day_manager.day < day:
		_next_morning()


func _town_npc(id: String) -> Node:
	for npc in main.zones["town"]["npcs"].npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if _finished:
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			day_manager.time_paused = true
			day_manager.minutes_into_day = 9 * 60.0
			var farm_structures: Node = main.zones["farm"]["structures"]
			_check(farm_structures.market == main.market, "the shipping box sells through the market")
			_check(_town_npc(CaravanScript.NPC_ID) == null, "no Tully on Monday")
			_check(not main.caravan.is_here(1) and main.caravan.days_until_next(1) == 2, "he comes Wednesday")
			# -- A big load floods the shelf --
			var value := ItemDB.sell_value("glow_melon")
			var units := int(ceil(MarketRules.CAPACITY / float(value))) + 2
			player.set_credits(0)
			_check(farm_structures.add_to_shipping_box("glow_melon", units), "loaded %d melons" % units)
			_check(int(main.market.quote(farm_structures.shipping_contents)["total"]) == units * value,
				"the first load is quoted at list price")
			_next_morning()
			_check(int(player.credits) == units * value, "and paid at list price (%d)" % int(player.credits))
			_flood_mult = main.market.multiplier_for("glow_melon")
			_check(_flood_mult < 0.75, "the shelf is flooded (x%.2f)" % _flood_mult)
			# The shipping screen shows it.
			player.inventory.add_item("glow_melon", 3)
			main._bind_zone("farm")
			var shipping: Node = main.get_node("ShippingUI")
			shipping.open_box()
			var row := ""
			for label in shipping._row_labels:
				if label.visible and String(label.text).begins_with("Glow Melon"):
					row = String(label.text)
			_check(row.contains("-"), "the shipping row shows the drop: '%s'" % row)
			shipping.close()
			farm_structures.add_to_shipping_box("glow_melon", 3)
			player.inventory.remove_item("glow_melon", 3)
			_credits = int(player.credits)
			_next_morning()  # day 3, Wednesday
			var paid := int(player.credits) - _credits
			_check(paid < 3 * value and paid > 0, "the second load pays less (%d for 3)" % paid)
			_next(1)
		1:
			# -- Wednesday: Tully is at the stall --
			_check(day_manager.day == 3, "it's Wednesday (day %d)" % day_manager.day)
			var tully := _town_npc(CaravanScript.NPC_ID)
			_check(tully != null, "Tully is in town")
			if tully != null:
				var map: Node2D = main.zones["town"]["map"]
				_check(map.world_to_cell(tully.global_position) == CaravanScript.STAND_CELL, "at the market stall")
			_stall = main.caravan.offers.duplicate(true)
			_check(_stall.size() == 6, "six things on the stall (%d)" % _stall.size())
			_check(main.dialogue_context()["flags"].has("caravan_day"), "the town knows it's a caravan day")
			# Buy through the real store screen.
			var store: Node = main.get_node("StoreUI")
			main._on_caravan_requested(tully)
			_check(store.active, "his stall opens the store screen")
			var first := String(_stall[0]["item"])
			_check(store._row_ids[0] == first and store._row_text(first).contains("left"), "rows show his stock")
			player.set_credits(100000)
			var had: int = player.inventory.count_of(first)
			_press(store, "use_tool")
			_check(int(player.credits) == 100000 - int(_stall[0]["price"]), "paid his price (no hearts, no discount)")
			_check(player.inventory.count_of(first) == had + 1 or ItemDB.is_weapon(first), "got the goods")
			_check(int(main.caravan.offers[0]["qty"]) == int(_stall[0]["qty"]) - 1, "his stock counted down")
			for i in int(_stall[0]["qty"]) + 1:
				_press(store, "use_tool")
			_check(int(main.caravan.offers[0]["qty"]) == 0 and store._row_text(first).contains("sold out"),
				"and runs out")
			store.close()
			# Friendship pays.
			main.affinity.adjust(CaravanScript.NPC_ID, 5)
			main._on_caravan_requested(tully)
			var second := String(_stall[1]["item"])
			_check(int(store._offers[second]["price"]) == CaravanScript.price_after(int(_stall[1]["price"]), 5),
				"five hearts: 10%% off (%d)" % int(store._offers[second]["price"]))
			store.close()
			_next_morning()  # Thursday
			_check(_town_npc(CaravanScript.NPC_ID) == null, "gone on Thursday")
			_next(2)
		2:
			# -- The second Monday: a demand list --
			_go_to_day(8)
			_demand = main.market.demand.duplicate()
			_check(_demand.size() == 3, "Marta names three things on day 8 (%s)" % [_demand])
			var wanted := String(_demand[0])
			_check(is_equal_approx(main.market.multiplier_for(wanted), 1.4), "+40%% on %s" % wanted)
			_credits = int(player.credits)
			main.zones["farm"]["structures"].add_to_shipping_box(wanted, 2)
			_next_morning()
			_check(int(player.credits) - _credits == 2 * int(round(ItemDB.sell_value(wanted) * 1.4)),
				"and it ships at that price")
			# -- A trading post --
			var structures: Node = main.zones["farm"]["structures"]
			_check(structures.place_blueprint("trading_post", POST_CELL), "trading post placed")
			_go_to_day(day_manager.day + 4)
			_check(structures.is_trading_post_at(POST_CELL), "built")
			_check(structures.is_chest_at(POST_CELL + Vector2i(2, 1)), "its shelf opens from any of its cells")
			var shelf = structures.storage_inventory_at(POST_CELL)
			# The real screen, opened the way the game opens it.
			structures.interact_chest(POST_CELL)
			var storage_ui: Node = main.storage_ui
			_check(storage_ui.active and storage_ui._title.text.begins_with("Trading Post — Fair"),
				"the shelf screen opens on Fair ('%s')" % storage_ui._title.text)
			_press(storage_ui, "build_cycle")
			_check(structures.post_markup(POST_CELL) == 1 and storage_ui._title.text.contains("Bold"), "Q sets Bold")
			storage_ui.close()
			shelf.add_item("mutant_potato", 4)
			shelf.add_item("hoe", 1)
			shelf.add_item("ironroot", 10)
			_credits = int(player.credits)
			_next_morning()
			var expected := 4 * int(round(ItemDB.sell_value("mutant_potato") * 1.35)) \
				+ 2 * int(round(ItemDB.sell_value("ironroot") * 1.35))
			_check(int(player.credits) - _credits == expected, "six units sold at +35%% (%d, expected %d)"
				% [int(player.credits) - _credits, expected])
			_check(shelf.count_of("mutant_potato") == 0 and shelf.count_of("ironroot") == 8 and shelf.count_of("hoe") == 1,
				"in shelf order; the hoe stays")
			# -- Save and reload on a caravan day --
			while not main.caravan.is_here(day_manager.day):
				_next_morning()
			_stall = main.caravan.offers.duplicate(true)
			main.zones["farm"]["structures"].add_to_shipping_box("glow_melon", 40)
			_next_morning()
			while not main.caravan.is_here(day_manager.day):
				_next_morning()
			_stall = main.caravan.offers.duplicate(true)
			_flood_mult = main.market.multiplier_for("glow_melon")
			_demand = main.market.demand.duplicate()
			_check(game_state.save_game(player, main.zones, main.get_node("Settlers"),
				main.get_node("Animals"), main.get_node("Affinity")), "saved")
			main.queue_free()
			main = null
			_next(3)
		3:
			if ticks < 3:
				return false
			game_state.load_save_from_disk()
			_boot()
			_next(4)
		4:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			_check(is_equal_approx(main.market.multiplier_for("glow_melon"), _flood_mult), "the flood survives a reload")
			_check(main.market.demand == _demand, "so does the demand list")
			_check(main.caravan.offers == _stall, "and the stall's stock")
			_check(_town_npc(CaravanScript.NPC_ID) != null, "Tully is standing there after the reload")
			var structures: Node = main.zones["farm"]["structures"]
			_check(structures.post_markup(POST_CELL) == 1, "the post's markup")
			_check(structures.storage_inventory_at(POST_CELL).count_of("hoe") == 1, "and its shelf (the unsold hoe)")
			_finish()
			return true
	return false


func _finish() -> void:
	_finished = true
	_wipe()
	if failures.is_empty():
		print("ECONOMY SMOKE: all checks passed (flood + shipping screen, Tully's visit, stock, discount, demand week, trading post shelf/markup/sale, save/reload).")
		quit(0)
	else:
		for f in failures:
			print("ECONOMY SMOKE FAIL: %s" % f)
		quit(1)


func _finalize() -> void:
	if not _finished:
		print("ECONOMY SMOKE FAIL: the run ended at stage %d before finishing" % stage)
		for f in failures:
			print("ECONOMY SMOKE FAIL: %s" % f)
