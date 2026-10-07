extends CharacterBody2D
## The player character (v2 interaction model, 2026-10-07).
##
## Movement: 4-directional CharacterBody2D with idle/walk/tool animations per facing.
##
## Two action buttons, Stardew-style:
## - USE ("use_tool": Space / C / left mouse / pad X): swings the selected hotbar item at the
##   TARGET CELL — till, water, chop, mine, cut, plant, fertilise, eat — and, for compatibility
##   and convenience, also performs the instant interactions below when one is directly ahead.
##   Holding it repeats the swing; holding a direction too walks tile-by-tile while working.
## - INTERACT ("interact": E / X / right mouse / pad A): talk, open chests, sleep, use the
##   shipping box, harvest, pick forage, eat/plant the selected item. Never swings a tool.
##
## Target cell: the cell in front of the player (keyboard/pad), or — when the mouse has moved
## recently — the cell under the cursor if it's within one tile, else the neighbour toward it.
## scripts/target_cursor.gd draws it; describe_action() tells the HUD what pressing would do.
##
## Instant interactions fire once per discrete press (the _instant_armed press-edge latch), so a
## held key never re-opens a dialogue/chest or sleeps through several nights.
##
## The night rules (midnight sleepy drain, 2 AM forced pass-out, coffee) and save/load are
## unchanged from Phases 3-8 — see the "Night rules" block.

const Inventory := preload("res://scripts/inventory.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const CropDB := preload("res://scripts/crop_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const DayManagerScript := preload("res://scripts/day_manager.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")

signal energy_changed(current: float, max_energy: float)
signal npc_dialogue_requested(npc: Node)
signal credits_changed(current: int)
signal shipping_box_requested
signal zone_exit_requested(target_zone: String, entry_cell: Vector2i)
## The tile the player is aiming at changed (target_cursor.gd and the HUD prompt listen).
signal target_changed(cell: Vector2i)

## ~3.5 tiles/second at 16 px tiles — Stardew's walk feel.
const SPEED := 56.0
const CELL_SIZE := 16.0

## Energy per EFFECTIVE action (whiffs are free). Planting, harvesting, cutting weeds and eating
## cost nothing, Stardew-style; working the land and breaking things do.
const ENERGY_TILL := 1.0
const ENERGY_WATER := 1.0
const ENERGY_PLANT := 0.0
const ENERGY_HARVEST := 0.0
const ENERGY_CHOP := 1.0
const ENERGY_MINE := 1.0
const ENERGY_SCYTHE := 0.0
const ENERGY_BUILD := 1.25

## Watering-can capacity by tool tier (index = tier - 1).
const CAN_CAPACITY := ItemDB.CAN_CAPACITY
## How long the mouse counts as "in charge" of aiming after it last moved.
const MOUSE_AIM_SECONDS := 2.5

## -- Night rules (2026-07-11, Stardew-style forced sleep) --
## From midnight a passive drain ticks (SLEEPY_DRAIN_PER_GAME_MINUTE); at 2 AM the player passes
## out regardless of energy unless a stay-awake item (coffee) was drunk tonight. Every night
## ending auto-saves. See GDD.md §4 "The night rules".
const FORCED_PASSOUT_MINUTES := 2.0 * 60.0
const SLEEPY_DRAIN_PER_GAME_MINUTE := 0.15

const FACINGS := ["south", "north", "east", "west"]
const FACING_VECTORS := {
	"south": Vector2(0, 1),
	"north": Vector2(0, -1),
	"east": Vector2(1, 0),
	"west": Vector2(-1, 0),
}

var facing := "south"
const BASE_MAX_ENERGY := 100.0
var max_energy := BASE_MAX_ENERGY
var energy := max_energy
var credits := 0
var using_tool := false
var stay_awake_tonight := false

var _instant_armed := true
var _interact_armed := true
var _modal_open_last_frame := false
var _stepping := false
var _step_target := Vector2.ZERO
var _mouse_aim_until := 0.0
var _last_target := Vector2i(-9999, -9999)
var _footstep_timer := 0.0

## -- World bindings (set by main.gd) --
var current_zone_id := "farm"
var zones: Dictionary = {}
var settlers: Node = null
var animals: Node = null
var affinity: Node = null
## Milestone B: skills (scripts/skills.gd) — tool energy costs shrink as the governing skill levels.
var skills: Node = null
var _zone_transitioning := false
var farm: Node = null
var test_map: Node = null
var structures: Node = null
var objects: Node = null
var builder: Node = null
var npcs: Node = null
var dialogue_ui: Node = null
var store_ui: Node = null
var ranch_store_ui: Node = null
var shipping_ui: Node = null
var menu_screen: Node = null
## Milestone B: the chest/storage screen (scripts/storage_ui.gd).
var storage_ui: Node = null
var inventory: Inventory = Inventory.new()

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("player")
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_play("idle")
	_give_starting_loadout()
	DayManager.time_advanced.connect(_on_time_advanced)


func _physics_process(delta: float) -> void:
	var modal_open := _in_dialogue() or _in_store() or _in_shipping() or _in_build_mode() \
		or _in_menu() or _in_storage()
	var use_pressed := _use_pressed()
	_instant_armed = instant_armed_next(_instant_armed, use_pressed, modal_open, _modal_open_last_frame)
	_interact_armed = instant_armed_next(_interact_armed, Input.is_action_pressed("interact"),
		modal_open, _modal_open_last_frame)
	_modal_open_last_frame = modal_open
	_update_target()
	if using_tool:
		velocity = Vector2.ZERO
		return
	if _in_dialogue() or _in_store() or _in_shipping() or _in_menu() or _in_storage() \
			or _zone_transitioning:
		velocity = Vector2.ZERO
		return
	if test_map != null:
		var exit: Dictionary = test_map.zone_exit_at(test_map.world_to_cell(global_position))
		if not exit.is_empty():
			_zone_transitioning = true
			velocity = Vector2.ZERO
			zone_exit_requested.emit(String(exit["target_zone"]), Vector2i(exit["entry_cell"]))
			return
	if _stepping:
		_process_step()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Interact: discrete presses only.
	if Input.is_action_pressed("interact") and not _in_build_mode():
		if _interact_armed:
			_interact_armed = false
			interact()
			if using_tool or _in_dialogue() or _in_store() or _in_shipping() or _in_storage():
				velocity = Vector2.ZERO
				return
	if use_pressed and not _in_build_mode():
		velocity = Vector2.ZERO
		if input != Vector2.ZERO:
			facing = facing_from_input(input, facing)
			_mouse_aim_until = 0.0
		var instant_allowed := _instant_armed
		_instant_armed = false
		use_tool(instant_allowed)
		return
	velocity = input * SPEED * _speed_multiplier()
	move_and_slide()
	facing = facing_from_input(input, facing)
	_play("walk" if input != Vector2.ZERO else "idle")
	_tick_footsteps(delta, input != Vector2.ZERO)


## Use-button state: keyboard/pad always; the mouse button only when not over a UI control.
func _use_pressed() -> bool:
	if not Input.is_action_pressed("use_tool"):
		return false
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _mouse_over_ui():
		# Only the mouse is holding it, and it's on the HUD: that click belongs to the UI.
		return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_C) \
			or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	return true


func _mouse_over_ui() -> bool:
	var vp := get_viewport()
	return vp != null and vp.gui_get_hovered_control() != null


func _speed_multiplier() -> float:
	return 1.0


func _tick_footsteps(delta: float, moving: bool) -> void:
	if not moving:
		_footstep_timer = 0.12
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	_footstep_timer = 0.32
	var surface := "grass"
	if test_map != null:
		var cell: Vector2i = test_map.world_to_cell(global_position)
		var t := String(test_map.terrain_at(cell))
		if t == "p":
			surface = "wood"
		elif test_map.is_soil_at(cell.x, cell.y) or (test_map.has_method("is_path_at") and test_map.is_path_at(cell)):
			surface = "dirt"
	Audio.play_sfx("footstep_" + surface, -6.0, 0.08)


func _process_step() -> void:
	var to_target := _step_target - global_position
	if to_target.length() <= 1.0:
		global_position = _step_target
		_stepping = false
		return
	velocity = to_target.normalized() * SPEED
	move_and_slide()
	_play("walk")
	if get_slide_collision_count() > 0:
		_stepping = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_aim_until = _now() + MOUSE_AIM_SECONDS
	elif event is InputEventMouseButton and event.pressed:
		_mouse_aim_until = _now() + MOUSE_AIM_SECONDS
		if not _in_any_modal():
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_hotbar(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_hotbar(-1)
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right") \
				or event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
			_mouse_aim_until = 0.0
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_slot_%d" % (i + 1)):
			_select_hotbar(i)
	if event.is_action_pressed("hotbar_next"):
		_cycle_hotbar(1)
	elif event.is_action_pressed("hotbar_prev"):
		_cycle_hotbar(-1)


func _select_hotbar(i: int) -> void:
	if i != inventory.selected_hotbar_index:
		inventory.select_hotbar(i)
		Audio.play_sfx("ui_tab", -8.0)


func _cycle_hotbar(step: int) -> void:
	_select_hotbar(posmod(inventory.selected_hotbar_index + step, Inventory.HOTBAR_SIZE))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _in_any_modal() -> bool:
	return _in_dialogue() or _in_store() or _in_shipping() or _in_menu() or _in_storage()


func bind_world(farm_node: Node, map_node: Node, structures_node: Node = null,
		npcs_node: Node = null, objects_node: Node = null) -> void:
	farm = farm_node
	test_map = map_node
	structures = structures_node
	npcs = npcs_node
	objects = objects_node
	if objects == null and map_node != null:
		objects = map_node.get_node_or_null("Objects")


## -- Targeting --

func _update_target() -> void:
	if test_map == null:
		return
	var cell := _target_cell()
	if cell != _last_target:
		_last_target = cell
		target_changed.emit(cell)


func mouse_aiming() -> bool:
	return _now() < _mouse_aim_until


## The logical cell the next action lands on (see class doc).
func _target_cell() -> Vector2i:
	var my_cell: Vector2i = test_map.world_to_cell(global_position)
	if mouse_aiming():
		var mouse_cell: Vector2i = test_map.world_to_cell(get_global_mouse_position())
		return target_cell_for(my_cell, facing, mouse_cell, true)
	return target_cell_for(my_cell, facing, Vector2i.ZERO, false)


func target_cell() -> Vector2i:
	return _target_cell() if test_map != null else Vector2i.ZERO


## Pure targeting rule: with the mouse in charge, the hovered cell if it's within one tile
## (including diagonals, excluding the player's own cell), else the neighbour toward it; without
## the mouse, the cell ahead in `facing_dir`.
static func target_cell_for(player_cell: Vector2i, facing_dir: String, mouse_cell: Vector2i,
		use_mouse: bool) -> Vector2i:
	if use_mouse:
		var d := mouse_cell - player_cell
		if d == Vector2i.ZERO:
			var fv: Vector2 = FACING_VECTORS.get(facing_dir, Vector2(0, 1))
			return player_cell + Vector2i(fv)
		if absi(d.x) <= 1 and absi(d.y) <= 1:
			return mouse_cell
		return player_cell + Vector2i(signi(d.x), signi(d.y))
	var v: Vector2 = FACING_VECTORS.get(facing_dir, Vector2(0, 1))
	return player_cell + Vector2i(v)


## Pure: which way to face to work on `to` from `from` (horizontal wins ties, like movement).
static func facing_toward(from: Vector2i, to: Vector2i, current: String) -> String:
	var d := to - from
	if d == Vector2i.ZERO:
		return current
	return facing_from_input(Vector2(d), current)


func _face_target(cell: Vector2i) -> void:
	if test_map == null:
		return
	facing = facing_toward(test_map.world_to_cell(global_position), cell, facing)


## -- What would pressing do? (HUD prompt + cursor colour) --

## {"use": verb or "", "interact": verb or ""} for the current target.
func describe_action() -> Dictionary:
	var out := {"use": "", "interact": ""}
	if test_map == null or farm == null:
		return out
	var cell := _target_cell()
	var instant := _instant_target(cell)
	var instant_interact := _instant_target(cell, false)
	if instant != "" or instant_interact != "":
		out["interact"] = instant_interact
		out["use"] = instant
		if instant == "" and objects != null and objects.has_object(cell):
			out["use"] = "Pick up"
		return out
	if farm.can_harvest(cell):
		out["interact"] = "Harvest"
		out["use"] = "Harvest"
		return out
	if objects != null and objects.is_forage_at(cell):
		out["interact"] = "Pick up"
	var slot := inventory.get_selected_slot()
	var item_id := String(slot.get("item_id", ""))
	var kind := ItemDB.tool_kind(item_id)
	if farm.is_dead(cell) and (kind != "" or item_id == ""):
		out["use"] = "Clear"
		out["interact"] = "Clear"
		return out
	if objects != null and objects.has_object(cell) and not objects.is_forage_at(cell):
		var okind := String(objects.kind_at(cell))
		var tk := "weapon" if ItemDB.is_weapon(item_id) else kind
		var effect := WorldObjectDB.tool_effect(okind, tk, inventory.selected_tool_tier())
		if effect == WorldObjectDB.HIT:
			out["use"] = _verb_for(okind)
		elif effect == WorldObjectDB.TOO_WEAK:
			out["use"] = "Too tough"
		return out
	match kind:
		"hoe":
			if farm.can_till(cell):
				out["use"] = "Till"
		"watering_can":
			if _is_water(cell):
				out["use"] = "Refill"
			elif farm.can_water(cell):
				out["use"] = "Water" if _can_water_left() > 0 else "Empty"
	if String(ItemDB.get_item(item_id).get("type", "")) == "placeable":
		if _can_place_at(cell, item_id):
			out["use"] = "Place"
		return out
	if ItemDB.is_seed(item_id):
		var crop := _crop_for_seed(item_id)
		if crop != "" and farm.plant_check(cell, crop) == farm.OK:
			out["use"] = "Plant"
			out["interact"] = "Plant"
		elif crop != "" and farm.plant_check(cell, crop) == farm.WRONG_SEASON:
			out["use"] = "Wrong season"
	elif ItemDB.is_fertilizer(item_id) and farm.can_fertilize(cell, ItemDB.fertilizer_level(item_id)):
		out["use"] = "Fertilize"
		out["interact"] = "Fertilize"
	elif ItemDB.is_consumable(item_id):
		if out["interact"] == "":
			out["interact"] = "Eat" if ItemDB.is_edible(item_id) else "Use"
	return out


func _verb_for(object_kind: String) -> String:
	match WorldObjectDB.tool_of(object_kind):
		"pickup":
			return "Pick up"
		"axe":
			return "Chop"
		"pickaxe":
			return "Break"
		"scythe", "any":
			return "Clear"
	return "Hit"


## The instant interaction available at `cell`, as a verb ("" = none).
func _instant_target(cell: Vector2i, for_use: bool = true) -> String:
	if structures != null:
		if structures.is_chest_at(cell):
			return "Open"
		if structures.is_bed_at(cell):
			return "Sleep"
		if structures.is_shipping_box_at(cell):
			return "Ship"
	if npcs != null and npcs.npc_at(cell) != null:
		return "Talk"
	# Milestone B: crafted chests and machines. The Use button with an axe or pickaxe in hand
	# picks a placed object back up instead (Stardew's left-click), so it skips these verbs.
	if objects != null:
		var held := String(inventory.get_selected_slot().get("item_id", ""))
		var pickup_tool := ItemDB.tool_kind(held) == "axe" or ItemDB.tool_kind(held) == "pickaxe"
		if not (for_use and pickup_tool):
			var verb: String = objects.instant_verb(cell, held)
			if verb != "":
				return verb
	return ""


## -- USE button --

## Instant interactions first (chest/bed/box/NPC, press-edge only), then the selected item's
## action at the target cell. See class doc.
func use_tool(instant_allowed: bool = true) -> void:
	if test_map == null:
		return
	var cell := _target_cell()
	if mouse_aiming():
		_face_target(cell)
	if _instant_target(cell) != "":
		if instant_allowed:
			_do_instant(cell)
		return
	if energy <= 0.0:
		return
	_resolve_use(cell)


## INTERACT button: instant interactions, harvesting, forage, and using the selected item.
func interact() -> void:
	if test_map == null or farm == null:
		return
	var cell := _target_cell()
	if mouse_aiming():
		_face_target(cell)
	if _instant_target(cell, false) != "":
		_do_instant(cell)
		return
	# A placed machine that's busy (or idle with nothing loadable in hand) still answers: it
	# reports what it's doing.
	if objects != null and WorldObjectDB.is_placed(String(objects.kind_at(cell))):
		objects.interact_placed(cell, self)
		return
	if farm.can_harvest(cell):
		_harvest(cell)
		return
	if objects != null and objects.is_forage_at(cell):
		if not objects.pick(cell, inventory).is_empty():
			_lock_for(0.2)
		return
	if farm.is_dead(cell):
		farm.clear_dead(cell)
		Audio.play_sfx("scythe", -4.0)
		return
	var item_id := String(inventory.get_selected_slot().get("item_id", ""))
	if ItemDB.is_seed(item_id) or ItemDB.is_fertilizer(item_id):
		_resolve_use(cell)
	elif ItemDB.is_consumable(item_id):
		_consume_food(item_id)


func _do_instant(cell: Vector2i) -> void:
	if structures != null and structures.is_chest_at(cell):
		structures.interact_chest(cell)
		Audio.play_sfx("chest_open", -4.0)
		return
	if structures != null and structures.is_bed_at(cell):
		_sleep_in_bed()
		return
	if structures != null and structures.is_shipping_box_at(cell):
		Audio.play_sfx("chest_open", -6.0)
		shipping_box_requested.emit()
		return
	if npcs != null:
		var npc: Node = npcs.npc_at(cell)
		if npc != null:
			npc_dialogue_requested.emit(npc)
			return
	if objects != null:
		objects.interact_placed(cell, self)


func _resolve_use(cell: Vector2i) -> void:
	if farm == null:
		return
	# Harvesting isn't tool-gated (Stardew).
	if farm.can_harvest(cell):
		_harvest(cell)
		return
	var slot := inventory.get_selected_slot()
	var item_id := String(slot.get("item_id", ""))
	var kind := ItemDB.tool_kind(item_id)
	var tier := inventory.selected_tool_tier()
	var is_weapon := ItemDB.is_weapon(item_id)
	if farm.is_dead(cell) and (kind != "" or is_weapon):
		_swing()
		farm.clear_dead(cell)
		Audio.play_sfx("scythe", -2.0)
		Fx.burst(test_map.get_global_cell_center(cell), "grass", Vector2.UP, 0.6)
		return
	if objects != null and objects.has_object(cell):
		if objects.is_forage_at(cell):
			objects.pick(cell, inventory)
			_lock_for(0.2)
			return
		if kind != "" or is_weapon:
			_swing()
			var result: Dictionary = objects.hit(cell, "weapon" if is_weapon else kind, tier, global_position)
			var r := String(result.get("result", ""))
			if r == "hit" or r == "destroyed":
				var cost := ENERGY_SCYTHE if kind == "scythe" or WorldObjectDB.tool_of(String(result.get("kind", ""))) == "any" \
					else (ENERGY_CHOP if kind == "axe" else ENERGY_MINE)
				set_energy(energy - cost * _skill_multiplier(kind))
			elif r == WorldObjectDB.WRONG_TOOL:
				Audio.play_sfx("tool_whiff", -6.0)
		return
	if String(ItemDB.get_item(item_id).get("type", "")) == "placeable":
		_place(cell, item_id)
		return
	match kind:
		"hoe":
			_swing()
			if farm.till(cell):
				set_energy(energy - ENERGY_TILL * _skill_multiplier("hoe"))
				var at: Vector2 = test_map.get_global_cell_center(cell)
				Audio.play_sfx_at("hoe", at)
				Fx.burst(at, "dirt", Vector2.UP, 1.0)
			else:
				Audio.play_sfx("tool_whiff", -6.0)
			return
		"watering_can":
			_water(cell)
			return
		"axe", "pickaxe", "scythe":
			_swing()
			if kind == "pickaxe" and test_map.has_method("has_floor") and test_map.has_floor(cell):
				var item := String(test_map.remove_floor(cell))
				if item != "" and objects != null:
					objects.spawn_pickup(item, 1, test_map.get_global_cell_center(cell), Vector2.UP)
				Audio.play_sfx_at("mine", test_map.get_global_cell_center(cell))
				return
			Audio.play_sfx("tool_whiff", -6.0)
			return
	if is_weapon:
		_swing()
		Audio.play_sfx("swing", -4.0)
		return
	if ItemDB.is_seed(item_id):
		_plant(cell, item_id)
	elif ItemDB.is_fertilizer(item_id):
		if farm.fertilize(cell, ItemDB.fertilizer_level(item_id)):
			inventory.remove_item(item_id, 1)
			_lock_for(0.2)
			Audio.play_sfx_at("plant", test_map.get_global_cell_center(cell))
			Fx.burst(test_map.get_global_cell_center(cell), "dirt", Vector2.UP, 0.5)
	elif ItemDB.is_consumable(item_id):
		_consume_food(item_id)


func _skill_multiplier(tool_kind: String) -> float:
	return skills.energy_multiplier(tool_kind) if skills != null else 1.0


## Sets a crafted placeable down at `cell` (Milestone B): paths become floor, everything else
## a placed world object.
func _place(cell: Vector2i, item_id: String) -> void:
	var placed := false
	if test_map.has_method("floor_kind_for_item") and test_map.floor_kind_for_item(item_id) != "":
		placed = test_map.place_floor(cell, item_id, farm)
	elif objects != null:
		placed = objects.place_item(item_id, cell)
	if placed:
		inventory.remove_item(item_id, 1)
		_lock_for(0.15)
	else:
		Audio.play_sfx("tool_whiff", -8.0)


func _can_place_at(cell: Vector2i, item_id: String) -> bool:
	if test_map.has_method("floor_kind_for_item") and test_map.floor_kind_for_item(item_id) != "":
		return test_map.can_place_floor(cell, farm)
	var kind := WorldObjectDB.kind_for_item(item_id)
	return kind != "" and objects != null and objects.can_place(kind, cell, true) \
		and (farm == null or farm.get_plot(cell).is_empty())


func _crop_for_seed(item_id: String) -> String:
	var item := ItemDB.get_item(item_id)
	if bool(item.get("mixed", false)):
		return farm.random_seasonal_crop() if farm != null else ""
	var crop := String(item.get("crop_id", ""))
	return crop if crop != "" else CropDB.crop_for_seed(item_id)


func _plant(cell: Vector2i, item_id: String) -> void:
	var crop_id := _crop_for_seed(item_id)
	if crop_id == "":
		return
	var check: String = farm.plant_check(cell, crop_id)
	if check == farm.WRONG_SEASON:
		Fx.float_text(test_map.get_global_cell_center(cell) + Vector2(0, -8), "Wrong season", Color("#ffc948"))
		Audio.play_sfx("ui_error", -6.0)
		return
	if farm.plant(cell, crop_id):
		inventory.remove_item(item_id, 1)
		set_energy(energy - ENERGY_PLANT)
		_lock_for(0.18)
		_squash()
		Audio.play_sfx_at("plant", test_map.get_global_cell_center(cell))
		Fx.burst(test_map.get_global_cell_center(cell), "dirt", Vector2.UP, 0.4)
		Events.xp_gained.emit("farming", 1)


func _harvest(cell: Vector2i) -> void:
	var result: Dictionary = farm.harvest(cell)
	if result.is_empty():
		return
	var item_id := String(result.get("item_id", ""))
	var count := int(result.get("count", 1))
	set_energy(energy - ENERGY_HARVEST)
	var at: Vector2 = test_map.get_global_cell_center(cell)
	var leftover := inventory.add_item(item_id, count)
	if count - leftover > 0:
		Events.item_gained.emit(item_id, count - leftover)
	if leftover > 0 and objects != null:
		objects.spawn_pickup(item_id, leftover, at)
	Audio.play_sfx_at("harvest", at)
	Fx.burst(at + Vector2(0, -6), "sparkle", Vector2.UP, 0.7)
	_lock_for(0.2)
	_squash()
	var crop_id := String(result.get("crop_id", ""))
	Events.crop_harvested.emit(crop_id, count)
	Events.xp_gained.emit("farming", farm.harvest_xp(ItemDB.sell_value(item_id)) * count)


func _water(cell: Vector2i) -> void:
	var slot_index := inventory.selected_hotbar_index
	var at: Vector2 = test_map.get_global_cell_center(cell)
	_lock_for(0.32)
	_play("idle")
	if _is_water(cell):
		_set_can_water(slot_index, _can_capacity())
		Audio.play_sfx_at("refill", at)
		Fx.burst(at, "water", Vector2.UP, 1.2)
		Fx.float_text(at + Vector2(0, -8), "Refilled", Color("#9cc8d2"))
		return
	if _can_water_left() <= 0:
		Fx.float_text(global_position + Vector2(0, -22), "Can's empty", Color("#9cc8d2"))
		Audio.play_sfx("ui_error", -8.0)
		return
	if farm.water(cell):
		_set_can_water(slot_index, _can_water_left() - 1)
		set_energy(energy - ENERGY_WATER * _skill_multiplier("watering_can"))
		Audio.play_sfx_at("water", at)
		Fx.burst(at + Vector2(0, -2), "water", Vector2.DOWN, 1.0)
	else:
		Audio.play_sfx("tool_whiff", -8.0)


func _is_water(cell: Vector2i) -> bool:
	return test_map != null and String(test_map.terrain_at(cell)) == "W"


func _can_capacity() -> int:
	return ItemDB.can_capacity(inventory.selected_tool_tier())


## Water left in the selected watering can (a can without a recorded level counts as full).
func _can_water_left() -> int:
	var slot := inventory.get_selected_slot()
	return int(slot.get("water", _can_capacity()))


func _set_can_water(index: int, amount: int) -> void:
	var slot: Dictionary = inventory.get_slot(index).duplicate()
	if slot.is_empty():
		return
	slot["water"] = maxi(amount, 0)
	inventory.set_slot(index, slot)


## The shared swing animation (locks movement until it finishes).
func _swing() -> void:
	using_tool = true
	velocity = Vector2.ZERO
	_play("tool")


## Locks movement briefly for non-swing actions (planting, watering, eating).
func _lock_for(seconds: float) -> void:
	using_tool = true
	velocity = Vector2.ZERO
	if not is_inside_tree():
		using_tool = false
		return
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if using_tool and sprite.animation.begins_with("tool") == false:
			using_tool = false
			_play("idle"))


## A little squash-and-stretch for crouching actions.
func _squash() -> void:
	if sprite == null:
		return
	sprite.scale = Vector2(1.12, 0.88)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## -- Energy / night rules --

func set_energy(value: float) -> void:
	var result := apply_energy_delta(energy, max_energy, value - energy)
	energy = result["energy"]
	energy_changed.emit(energy, max_energy)
	if result["passed_out"]:
		_pass_out()


func _on_time_advanced(prev_minutes: float, new_minutes: float) -> void:
	var drained := late_night_drain(prev_minutes, new_minutes, SLEEPY_DRAIN_PER_GAME_MINUTE)
	if drained > 0.0:
		set_energy(energy - drained)
	var now: float = DayManager.minutes_into_day
	if should_force_passout(now, stay_awake_tonight):
		_pass_out()
	elif stay_awake_tonight and survived_night(prev_minutes, now):
		stay_awake_tonight = false


func _pass_out() -> void:
	_end_day()


func _sleep_in_bed() -> void:
	_end_day()


## The one way a day ends: jump to 6 AM (day_started fires), wake rested, auto-save.
func _end_day() -> void:
	stay_awake_tonight = false
	DayManager.skip_to_next_morning()
	energy = max_energy
	energy_changed.emit(energy, max_energy)
	_refill_cans()
	if not zones.is_empty():
		GameState.save_game(self, zones, settlers, animals, affinity)


## A good night's sleep tops the watering cans back up (one less chore — the well is implied).
func _refill_cans() -> void:
	for i in inventory.slots.size():
		var slot: Dictionary = inventory.get_slot(i)
		if ItemDB.tool_kind(String(slot.get("item_id", ""))) == "watering_can" and slot.has("water"):
			var s := slot.duplicate()
			s.erase("water")
			inventory.set_slot(i, s)


func _in_build_mode() -> bool:
	return builder != null and bool(builder.active)


func _in_dialogue() -> bool:
	return dialogue_ui != null and bool(dialogue_ui.active)


func _in_store() -> bool:
	return (store_ui != null and bool(store_ui.active)) \
		or (ranch_store_ui != null and bool(ranch_store_ui.active))


func _in_shipping() -> bool:
	return shipping_ui != null and bool(shipping_ui.active)


func _in_menu() -> bool:
	return menu_screen != null and bool(menu_screen.active)


func _in_storage() -> bool:
	return storage_ui != null and bool(storage_ui.active)


func end_zone_transition() -> void:
	_zone_transitioning = false


## Kept for older tools/tests: resolves a USE action at an explicit cell.
func _interact(cell: Vector2i) -> void:
	_resolve_use(cell)


## Eats/uses one of the selected consumable: energy, HP, rads, and coffee's stay-awake charge.
func _consume_food(item_id: String) -> void:
	if inventory.remove_item(item_id, 1) != 1:
		return
	if ItemDB.grants_stay_awake(item_id):
		stay_awake_tonight = true
	var restored := ItemDB.energy_restored(item_id)
	if restored > 0:
		set_energy(energy + float(restored))
	Audio.play_sfx("eat" if ItemDB.is_edible(item_id) else "heal", -2.0)
	Fx.float_text(global_position + Vector2(0, -22), "+%d" % restored if restored > 0 else "", Color("#95ac49"))
	_lock_for(0.35)
	_squash()


## -- Credits --

func set_credits(value: int) -> void:
	credits = maxi(0, value)
	credits_changed.emit(credits)


func add_credits(amount: int) -> void:
	set_credits(credits + amount)


func add_items(items: Dictionary) -> void:
	for item_id in items:
		var count := int(items[item_id])
		var leftover := inventory.add_item(String(item_id), count)
		if count - leftover > 0:
			Events.item_gained.emit(String(item_id), count - leftover)


## -- Save / load --

func save_state() -> Dictionary:
	return {
		"x": global_position.x,
		"y": global_position.y,
		"facing": facing,
		"energy": energy,
		"credits": credits,
		"current_zone": current_zone_id,
		"inventory": SaveData.encode_inventory(inventory.slots, inventory.selected_hotbar_index),
	}


func load_state(data: Dictionary) -> void:
	global_position = Vector2(float(data.get("x", global_position.x)),
		float(data.get("y", global_position.y)))
	velocity = Vector2.ZERO
	current_zone_id = String(data.get("current_zone", "farm"))
	if String(data.get("facing", "")) in FACINGS:
		facing = String(data["facing"])
	energy = clampf(float(data.get("energy", max_energy)), 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
	credits = int(data.get("credits", 0))
	credits_changed.emit(credits)
	var inventory_data = data.get("inventory", {})
	if inventory_data is Dictionary and not (inventory_data as Dictionary).is_empty():
		var decoded := SaveData.decode_inventory(inventory_data)
		inventory.restore(decoded["slots"], int(decoded["selected_hotbar_index"]))
	_play("idle")


func _grant_item(result: Dictionary) -> void:
	inventory.add_item(String(result.get("item_id", "")), int(result.get("count", 0)))


## Starting loadout: the five farm tools (tier 1) and mum's tin of radish seeds — a 4-day crop,
## so the first harvest lands inside the first week.
func _give_starting_loadout() -> void:
	for tool_id in ["hoe", "watering_can", "axe", "pickaxe", "scythe"]:
		inventory.add_tool(tool_id, 1)
	inventory.add_item("seed_rain_radish", 15)


## -- Pure rules (unit tested) --

static func facing_from_input(input: Vector2, current: String) -> String:
	if input == Vector2.ZERO:
		return current
	if absf(input.x) >= absf(input.y) and input.x != 0.0:
		return "east" if input.x > 0.0 else "west"
	return "south" if input.y > 0.0 else "north"


## Press-edge latch for instant interactions: re-arms on release; a press held while (or in the
## frame after) any modal was open never counts.
static func instant_armed_next(armed: bool, pressed: bool, modal_open: bool,
		modal_was_open: bool) -> bool:
	if not pressed:
		return true
	if modal_open or modal_was_open:
		return false
	return armed


static func apply_energy_delta(current: float, max_energy_value: float, delta: float) -> Dictionary:
	var new_energy := clampf(current + delta, 0.0, max_energy_value)
	var passed_out := current > 0.0 and new_energy <= 0.0
	return {"energy": new_energy, "passed_out": passed_out}


static func late_night_drain(prev_minutes: float, new_minutes: float, rate: float) -> float:
	var window_end := float(DayManagerScript.DAY_START_MINUTES)
	if new_minutes >= prev_minutes:
		return maxf(0.0, minf(new_minutes, window_end) - minf(prev_minutes, window_end)) * rate
	return minf(new_minutes, window_end) * rate


static func should_force_passout(minutes: float, stay_awake: bool) -> bool:
	return not stay_awake \
		and minutes >= FORCED_PASSOUT_MINUTES \
		and minutes < float(DayManagerScript.DAY_START_MINUTES)


static func survived_night(prev_minutes: float, new_minutes: float) -> bool:
	return prev_minutes < float(DayManagerScript.DAY_START_MINUTES) \
		and new_minutes >= float(DayManagerScript.DAY_START_MINUTES)


func _play(action: String) -> void:
	var animation := "%s_%s" % [action, facing]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation) \
			and (sprite.animation != animation or not sprite.is_playing()):
		sprite.play(animation)


func _on_sprite_animation_finished() -> void:
	if using_tool:
		using_tool = false
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if _use_pressed() and input != Vector2.ZERO and not mouse_aiming():
			var dir: Vector2 = FACING_VECTORS.get(facing, Vector2.ZERO)
			_step_target = global_position + dir * CELL_SIZE
			_stepping = true
		else:
			_play("idle")
