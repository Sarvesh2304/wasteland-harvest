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
const Combat := preload("res://scripts/combat.gd")
const Radiation := preload("res://scripts/radiation.gd")

signal energy_changed(current: float, max_energy: float)
signal npc_dialogue_requested(npc: Node)
signal credits_changed(current: int)
signal shipping_box_requested
signal zone_exit_requested(target_zone: String, entry_cell: Vector2i)
## The tile the player is aiming at changed (target_cursor.gd and the HUD prompt listen).
signal target_changed(cell: Vector2i)
## Milestone C: health, radiation, gear and death (the HUD and main.gd's expedition flow listen).
signal hp_changed(current: float, max_hp: float)
signal rads_changed(rads: float)
signal equipment_changed
signal died
## A lore note or blueprint from the pack wants reading (main.gd shows it): `item_id` is which.
signal note_read_requested(item_id: String)

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

## -- Milestone C: health, radiation, gear --
const BASE_MAX_HP := 100.0
var max_hp := BASE_MAX_HP
var hp := BASE_MAX_HP
## Radiation exposure, 0..Radiation.MAX_RADS: shrinks the HP/energy ceilings (scripts/radiation.gd).
var rads := 0.0
var dead := false
## Worn gear by slot (item ids, "" = nothing): armour, rad resistance, speed.
var equipment := {"head": "", "body": "", "feet": ""}
## The active zone's enemy director (scripts/enemies.gd), or null outside the ruins.
var enemies: Node = null
## Background rads/second where the player is (set by main.gd's expedition flow per level).
var ambient_rads := 0.0
var _iframes := 0.0
var _knock := Vector2.ZERO
var _attack_cd := 0.0
var _boost_until := 0.0
var _boost_mult := 1.0
var _geiger_acc := 0.0
var _hp_emit_acc := 0.0

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
## Milestone C: the yes/no prompt and note reader (scripts/confirm_ui.gd).
var confirm_ui: Node = null
var inventory: Inventory = Inventory.new()

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("player")
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	_play("idle")
	_give_starting_loadout()
	DayManager.time_advanced.connect(_on_time_advanced)


func _physics_process(delta: float) -> void:
	_iframes = maxf(_iframes - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_blink()
	if dead:
		velocity = Vector2.ZERO
		return
	var modal_open := _in_dialogue() or _in_store() or _in_shipping() or _in_build_mode() \
		or _in_menu() or _in_storage() or _in_confirm()
	if not modal_open and not _zone_transitioning:
		_tick_hazards(delta)
	# A hit's knockback overrides control (and any swing) for a moment.
	if _knock.length_squared() > 25.0:
		velocity = _knock
		move_and_slide()
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		return
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
			or _in_confirm() or _zone_transitioning:
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
			if using_tool or _in_dialogue() or _in_store() or _in_shipping() or _in_storage() \
					or _in_confirm():
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
	var mult := 1.0 + float(_gear_total("speed_bonus"))
	if _now() < _boost_until:
		mult *= _boost_mult
	return mult


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
	return _in_dialogue() or _in_store() or _in_shipping() or _in_menu() or _in_storage() \
		or _in_confirm()


func bind_world(farm_node: Node, map_node: Node, structures_node: Node = null,
		npcs_node: Node = null, objects_node: Node = null) -> void:
	farm = farm_node
	test_map = map_node
	structures = structures_node
	npcs = npcs_node
	objects = objects_node
	if objects == null and map_node != null:
		objects = map_node.get_node_or_null("Objects")
	enemies = map_node.get_node_or_null("Enemies") if map_node != null else null


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
	if ItemDB.item_type(item_id) == "equipment":
		out["use"] = "Equip"
		out["interact"] = "Equip"
		return out
	if item_id == "lore_note" or item_id == "blueprint":
		out["use"] = "Read"
		out["interact"] = "Read"
		return out
	if ItemDB.is_weapon(item_id) and enemies != null:
		out["use"] = "Attack" if ItemDB.get_item(item_id).get("weapon_class", "") != "ranged" else "Fire"
		return out
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
	elif ItemDB.item_type(item_id) == "equipment":
		equip(item_id)
	elif item_id == "lore_note" or item_id == "blueprint":
		note_read_requested.emit(item_id)


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
	if is_weapon:
		_attack(item_id)
		return
	if ItemDB.item_type(item_id) == "equipment":
		equip(item_id)
		return
	if item_id == "lore_note" or item_id == "blueprint":
		note_read_requested.emit(item_id)
		return
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
	if current_zone_id == "ruins":
		_die()  # collapsing out there is as bad as going down: main.gd's expedition flow
		return
	_end_day()


func _sleep_in_bed() -> void:
	_end_day()


## main.gd's expedition flow: end the day after Kael carries the player home.
func end_day(full_rest: bool = true) -> void:
	_end_day(full_rest)


## The one way a day ends: jump to 6 AM (day_started fires), wake rested, auto-save. After a
## collapse in the ruins (`full_rest` false) you wake with half energy and your HP as it was.
func _end_day(full_rest: bool = true) -> void:
	stay_awake_tonight = false
	DayManager.skip_to_next_morning()
	set_rads(Radiation.after_sleep(rads))
	energy = max_energy if full_rest else max_energy * 0.5
	energy_changed.emit(energy, max_energy)
	if not dead and full_rest:
		hp = effective_max_hp()
		hp_changed.emit(hp, effective_max_hp())
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


func _in_confirm() -> bool:
	return confirm_ui != null and bool(confirm_ui.active)


func end_zone_transition() -> void:
	_zone_transitioning = false


## Freezes the player for a scripted transition (main.gd's expedition fades); released by
## end_zone_transition when the new zone is bound.
func begin_zone_transition() -> void:
	_zone_transitioning = true
	velocity = Vector2.ZERO


## Kept for older tools/tests: resolves a USE action at an explicit cell.
func _interact(cell: Vector2i) -> void:
	_resolve_use(cell)


## Eats/uses one of the selected consumable: energy, HP, rads, a speed boost, and coffee's
## stay-awake charge. Medicine that would do nothing (a bandage at full health, a purifier with
## no rads) stays in the pack.
func _consume_food(item_id: String) -> void:
	var heals := ItemDB.hp_restored(item_id)
	var cleans := ItemDB.rad_removed(item_id)
	var restored := ItemDB.energy_restored(item_id)
	var boost := float(ItemDB.get_item(item_id).get("speed_boost", 0.0))
	if ItemDB.item_type(item_id) == "medicine" and restored <= 0 and boost <= 0.0:
		var useful := (heals > 0 and hp < effective_max_hp()) or (cleans > 0 and rads > 0.0)
		if not useful:
			Fx.float_text(hit_center() + Vector2(0, -16), "Not needed", Color("#ffedb1"))
			Audio.play_sfx("ui_error", -8.0)
			return
	if inventory.remove_item(item_id, 1) != 1:
		return
	if ItemDB.grants_stay_awake(item_id):
		stay_awake_tonight = true
	if restored > 0:
		set_energy(energy + float(restored))
	if heals > 0:
		heal(float(heals))
	if cleans > 0:
		set_rads(rads - float(cleans))
	if boost > 0.0:
		_boost_mult = boost
		_boost_until = _now() + 60.0
	Audio.play_sfx("eat" if ItemDB.is_edible(item_id) else "heal", -2.0)
	var text := ""
	if heals > 0:
		text = "+%d HP" % heals
	elif cleans > 0:
		text = "-%d rads" % cleans
	elif restored > 0:
		text = "+%d" % restored
	Fx.float_text(global_position + Vector2(0, -22), text,
		Color("#e84030") if heals > 0 else (Color("#86e83e") if cleans > 0 else Color("#95ac49")))
	if heals > 0:
		Fx.burst(hit_center(), "heart", Vector2.UP, 0.6)
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
		"hp": hp,
		"rads": rads,
		"equipment": equipment.duplicate(),
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
	var gear = data.get("equipment", {})
	if gear is Dictionary:
		for slot in equipment:
			var id := String((gear as Dictionary).get(slot, ""))
			equipment[slot] = id if ItemDB.has_item(id) else ""
	equipment_changed.emit()
	rads = Radiation.clamp_rads(float(data.get("rads", 0.0)))
	rads_changed.emit(rads)
	hp = clampf(float(data.get("hp", effective_max_hp())), 1.0, effective_max_hp())
	hp_changed.emit(hp, effective_max_hp())
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


## -- Combat (Milestone C) --

## The player's body centre (hit tests, projectiles, effects).
func hit_center() -> Vector2:
	return global_position + Vector2(0, -4)


## Swing or fire the weapon in hand toward the aim (mouse when it's in charge, else facing).
func _attack(item_id: String) -> void:
	var item := ItemDB.get_item(item_id)
	var aim := _aim_vector()
	facing = facing_from_input(aim, facing)
	if String(item.get("weapon_class", "melee")) == "ranged":
		_fire(item_id, item, aim)
	else:
		_melee(item_id, item, aim)


func _aim_vector() -> Vector2:
	if mouse_aiming():
		var v := get_global_mouse_position() - hit_center()
		if v.length() > 2.0:
			return v.normalized()
	return FACING_VECTORS.get(facing, Vector2.DOWN)


func _melee(item_id: String, item: Dictionary, aim: Vector2) -> void:
	var reach := float(item.get("reach", 18))
	_swing_timed(Combat.swing_seconds(item_id))
	set_energy(energy - Combat.ENERGY_PER_SWING)
	Audio.play_sfx("swing", -3.0, 0.1)
	_slash_fx(aim)
	var hits := 0
	if enemies != null:
		hits = enemies.melee_attack(hit_center(), aim, reach, int(item.get("damage", 5)),
			float(item.get("knockback", 80)), _damage_multiplier())
		enemies.noise(global_position, Combat.NOISE_MELEE)
	if hits > 0:
		Audio.play_sfx("hit", -2.0)
		Fx.shake(1.0 + 0.5 * hits, 0.08)
		_hitstop(0.045)
		return
	# Nothing in the arc: the swing still clears junk and weeds at the target, like before.
	var cell := _target_cell()
	if farm != null and farm.is_dead(cell):
		farm.clear_dead(cell)
	elif objects != null and objects.has_object(cell) and not objects.is_forage_at(cell):
		var result: Dictionary = objects.hit(cell, "weapon", inventory.selected_tool_tier(), global_position)
		if String(result.get("result", "")) == "destroyed" and enemies != null:
			enemies.set_cell_solid(cell, false)


func _fire(item_id: String, item: Dictionary, aim: Vector2) -> void:
	if _attack_cd > 0.0:
		return
	var ammo := String(item.get("ammo_item", ""))
	if ammo != "" and inventory.count_of(ammo) <= 0:
		Audio.play_sfx("gun_empty", -2.0)
		Fx.float_text(hit_center() + Vector2(0, -16), "No %s" % ItemDB.display_name(ammo), Color("#ffb72d"))
		_attack_cd = 0.4
		_lock_for(0.15)
		return
	if ammo != "":
		inventory.remove_item(ammo, 1)
	_attack_cd = float(item.get("cooldown", 0.5))
	_lock_for(0.14)
	_play("tool")
	Audio.play_sfx(_shot_sound(ammo), -1.0, 0.06)
	var muzzle := hit_center() + aim * 9.0
	var loud := Combat.noise_radius(item_id) >= Combat.NOISE_GUNSHOT
	_muzzle_fx(muzzle, aim, loud)
	if loud:
		Fx.shake(1.6, 0.07)
	if enemies != null:
		enemies.fire_player_shot(hit_center() + aim * 4.0, aim, item_id, _damage_multiplier())


func _shot_sound(ammo: String) -> String:
	match ammo:
		"crossbow_bolt":
			return "crossbow"
		"stone":
			return "slingshot"
		"rifle_ammo":
			return "gun_rifle"
		"shotgun_shells":
			return "gun_shotgun"
	return "gun_pistol"


## Plays the swing animation stretched or squeezed to last `seconds` (a weapon's cooldown).
func _swing_timed(seconds: float) -> void:
	_swing()
	var anim := sprite.animation
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		var frames := sprite.sprite_frames.get_frame_count(anim)
		var fps := sprite.sprite_frames.get_animation_speed(anim)
		if frames > 0 and fps > 0.0:
			sprite.speed_scale = (float(frames) / fps) / maxf(seconds, 0.1)


func _slash_fx(aim: Vector2) -> void:
	var path := "res://art/fx/slash.png"
	if not ResourceLoader.exists(path):
		Fx.burst(hit_center() + aim * 12.0, "dust", aim, 0.6)
		return
	var slash := Sprite2D.new()
	slash.texture = load(path)
	slash.hframes = 4
	slash.centered = false
	slash.offset = Vector2(0, -16)
	slash.rotation = aim.angle()
	slash.position = Vector2(0, -4)
	slash.z_index = 6
	add_child(slash)
	var tw := slash.create_tween()
	tw.tween_property(slash, "frame", 3, 0.16)
	tw.tween_callback(slash.queue_free)


func _muzzle_fx(at: Vector2, aim: Vector2, loud: bool) -> void:
	var path := "res://art/fx/muzzle_flash.png"
	if loud and ResourceLoader.exists(path):
		var flash := Sprite2D.new()
		flash.texture = load(path)
		flash.hframes = 3
		flash.rotation = aim.angle()
		flash.z_index = 6
		flash.position = at - global_position
		add_child(flash)
		var tw := flash.create_tween()
		tw.tween_property(flash, "frame", 2, 0.08)
		tw.tween_callback(flash.queue_free)
	Fx.burst(at, "sparkle" if loud else "dust", aim, 0.35)


## A beat of near-freeze on a solid hit, so it lands.
func _hitstop(seconds: float) -> void:
	if not is_inside_tree():
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)


func _combat_level() -> int:
	return skills.level("combat") if skills != null else 0


func _damage_multiplier() -> float:
	return Combat.skill_damage_multiplier(_combat_level())


## Hurt by an enemy, a shot or a blast. Ignored while invulnerable, dead or mid-transition.
func take_hit(raw: int, from: Vector2, knockback: float, rads_in: float = 0.0) -> void:
	if dead or _iframes > 0.0 or _zone_transitioning:
		return
	if rads_in > 0.0:
		add_rads(rads_in)
	var dmg := Combat.player_damage_taken(raw, armor(), _combat_level())
	if dmg <= 0:
		return
	hp = maxf(hp - float(dmg), 0.0)
	_iframes = Combat.PLAYER_IFRAMES
	_knock = Combat.knockback_velocity(from, global_position, knockback, Combat.PLAYER_WEIGHT)
	_stepping = false
	Fx.flash(sprite, 0.12)
	Fx.float_text(hit_center() + Vector2(0, -14), "-%d" % dmg, Color("#e84030"))
	Fx.burst(hit_center(), "blood", (global_position - from).normalized(), 0.6)
	Fx.shake(2.0, 0.15)
	Audio.play_sfx("player_hurt", -1.0)
	hp_changed.emit(hp, effective_max_hp())
	if hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(hp + amount, effective_max_hp())
	hp_changed.emit(hp, effective_max_hp())


## Sets HP directly (main.gd's death/respawn flow), clamped to the current ceiling.
func set_hp(value: float) -> void:
	hp = clampf(value, 0.0, effective_max_hp())
	hp_changed.emit(hp, effective_max_hp())


func effective_max_hp() -> float:
	return Radiation.effective_max(max_hp, rads)


## Exposure from the world, cut by worn gear.
func add_rads(amount: float) -> void:
	set_rads(rads + Radiation.absorbed(amount, rad_resist()))


func set_rads(value: float) -> void:
	var before := rads
	rads = Radiation.clamp_rads(value)
	if is_equal_approx(before, rads):
		return
	rads_changed.emit(rads)
	if hp > effective_max_hp():
		hp = effective_max_hp()
	hp_changed.emit(hp, effective_max_hp())
	if before < Radiation.WARN_AT and rads >= Radiation.WARN_AT:
		Audio.play_sfx("rad_warning", -2.0)
		Events.message.emit("You're irradiated. Your body won't hold as much.")
	if before < Radiation.SICKNESS_AT and rads >= Radiation.SICKNESS_AT:
		Audio.play_sfx("rad_warning", 0.0)
		Events.message.emit("Radiation sickness. Get out, or find a purifier.")


func _die() -> void:
	if dead:
		return
	dead = true
	using_tool = false
	_stepping = false
	velocity = Vector2.ZERO
	_knock = Vector2.ZERO
	sprite.speed_scale = 1.0
	_play("idle")
	sprite.rotation = deg_to_rad(90.0)
	sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
	Audio.play_sfx("player_death", 0.0)
	died.emit()


## Back on your feet (main.gd, after carrying the player home) at `hp_value`.
func revive(hp_value: float) -> void:
	dead = false
	_iframes = 0.0
	_knock = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	set_hp(hp_value)
	_play("idle")


func _blink() -> void:
	if sprite == null or dead:
		return
	sprite.self_modulate.a = 0.35 if _iframes > 0.0 and int(_iframes * 14.0) % 2 == 0 else 1.0


## Radiation where the player stands (sources + background), the geiger, and sickness.
func _tick_hazards(delta: float) -> void:
	var rate := ambient_rads
	if enemies != null and enemies.has_method("rad_rate_at"):
		rate += float(enemies.rad_rate_at(global_position))
	if rate > 0.0:
		add_rads(rate * delta)
		_geiger_acc += rate * delta * 6.0 + delta * 0.5
		if _geiger_acc >= 1.0:
			_geiger_acc = 0.0
			Audio.play_sfx("geiger_tick", -6.0, 0.2)
	if Radiation.is_sick(rads) and enemies != null and hp > 1.0:
		hp = maxf(hp - Radiation.SICKNESS_HP_PER_SECOND * delta, 1.0)
		_hp_emit_acc += delta
		if _hp_emit_acc >= 0.5:
			_hp_emit_acc = 0.0
			hp_changed.emit(hp, effective_max_hp())


## -- Gear --

## Wears `item_id` (from the pack) in its slot; whatever was there goes back in the pack.
func equip(item_id: String) -> bool:
	var slot := String(ItemDB.get_item(item_id).get("slot", ""))
	if not equipment.has(slot) or inventory.count_of(item_id) <= 0:
		return false
	var old := String(equipment[slot])
	inventory.remove_item(item_id, 1)
	equipment[slot] = item_id
	if old != "":
		var left := inventory.add_item(old, 1)
		if left > 0 and objects != null:
			objects.spawn_pickup(old, left, global_position)
	Audio.play_sfx("ui_confirm", -4.0)
	Fx.float_text(hit_center() + Vector2(0, -16), "Wearing " + ItemDB.display_name(item_id), Color("#ffedb1"))
	equipment_changed.emit()
	hp_changed.emit(hp, effective_max_hp())
	_lock_for(0.25)
	return true


## Takes off whatever is in `slot` into the pack (if there's room).
func unequip(slot: String) -> bool:
	var id := String(equipment.get(slot, ""))
	if id == "" or not inventory.can_add(id, 1):
		return false
	inventory.add_item(id, 1)
	equipment[slot] = ""
	equipment_changed.emit()
	return true


func armor() -> int:
	return int(_gear_total("armor"))


## Combined resistance of every worn piece (each cuts what the others let through).
func rad_resist() -> float:
	var through := 1.0
	for slot in equipment:
		var id := String(equipment[slot])
		if id != "":
			through *= 1.0 - clampf(float(ItemDB.get_item(id).get("rad_resist", 0.0)), 0.0, 0.9)
	return 1.0 - through


func _gear_total(field: String) -> float:
	var total := 0.0
	for slot in equipment:
		var id := String(equipment[slot])
		if id != "":
			total += float(ItemDB.get_item(id).get(field, 0.0))
	return total


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
	sprite.speed_scale = 1.0
	if using_tool:
		using_tool = false
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if _use_pressed() and input != Vector2.ZERO and not mouse_aiming():
			var dir: Vector2 = FACING_VECTORS.get(facing, Vector2.ZERO)
			_step_target = global_position + dir * CELL_SIZE
			_stepping = true
		else:
			_play("idle")
