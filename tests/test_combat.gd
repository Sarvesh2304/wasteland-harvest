extends "res://tests/test_case.gd"
## scripts/combat.gd, scripts/radiation.gd and scripts/enemy_db.gd: the pure combat rules
## (Milestone C) — melee arcs, armour, damage rolls, knockback, noise, pellets, projectile
## sweeps, the radiation meter, and the enemy catalogue + sheet frame maths.

const Combat := preload("res://scripts/combat.gd")
const Radiation := preload("res://scripts/radiation.gd")
const EnemyDB := preload("res://scripts/enemy_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func test_melee_arc_hits_in_front_within_reach() -> void:
	var o := Vector2.ZERO
	assert_true(Combat.in_melee_arc(o, Vector2.RIGHT, 18.0, Vector2(20, 0), 5.0), "ahead, reach + radius")
	assert_false(Combat.in_melee_arc(o, Vector2.RIGHT, 18.0, Vector2(30, 0), 5.0), "too far")
	assert_true(Combat.in_melee_arc(o, Vector2.RIGHT, 18.0, Vector2(12, 12), 5.0), "45 degrees off is inside a 150 arc")
	assert_false(Combat.in_melee_arc(o, Vector2.RIGHT, 18.0, Vector2(-15, 0), 5.0), "behind")
	assert_true(Combat.in_melee_arc(o, Vector2.RIGHT, 18.0, Vector2(-4, 0), 5.0), "point blank always hits")


func test_armor_never_turns_a_hit_into_nothing() -> void:
	assert_eq(Combat.damage_after_armor(10, 4), 6)
	assert_eq(Combat.damage_after_armor(3, 10), 1, "a real hit still hurts")
	assert_eq(Combat.damage_after_armor(0, 0), 0, "no hit, no damage")
	assert_eq(Combat.damage_after_armor(10, -3), 10, "negative armour ignored")


func test_player_damage_taken_applies_skill_then_armor() -> void:
	assert_eq(Combat.player_damage_taken(10, 0, 0), 10)
	assert_eq(Combat.player_damage_taken(10, 4, 0), 6)
	assert_eq(Combat.player_damage_taken(10, 0, 10), 8, "level 10 combat: -20%")
	assert_eq(Combat.player_damage_taken(0, 0, 0), 0)


func test_damage_roll_stays_in_band_and_is_deterministic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var first := []
	for i in 200:
		var r := Combat.roll_damage(10, rng)
		first.append(r["damage"])
		var lo := 8 if not r["crit"] else 12
		var hi := 12 if not r["crit"] else 18
		assert_true(int(r["damage"]) >= lo and int(r["damage"]) <= hi, "roll %d in band" % int(r["damage"]))
	rng.seed = 42
	for i in 200:
		assert_eq(Combat.roll_damage(10, rng)["damage"], first[i])


func test_knockback_points_away_and_respects_weight() -> void:
	var k := Combat.knockback_velocity(Vector2.ZERO, Vector2(10, 0), 100.0, 1.0)
	assert_true(_near(k.x, 100.0) and _near(k.y, 0.0), "away from the hitter")
	var heavy := Combat.knockback_velocity(Vector2.ZERO, Vector2(10, 0), 100.0, 2.5)
	assert_true(_near(heavy.x, 40.0), "heavy things barely budge")
	var same := Combat.knockback_velocity(Vector2(5, 5), Vector2(5, 5), 50.0, 1.0)
	assert_true(_near(same.length(), 50.0), "a degenerate hit still pushes")


func test_noise_guns_loud_melee_and_bows_quiet() -> void:
	assert_eq(Combat.noise_radius("rusty_pipe"), Combat.NOISE_MELEE)
	assert_eq(Combat.noise_radius("crossbow"), Combat.NOISE_QUIET_RANGED)
	assert_eq(Combat.noise_radius("slingshot"), Combat.NOISE_QUIET_RANGED)
	assert_eq(Combat.noise_radius("pipe_pistol"), Combat.NOISE_GUNSHOT)
	assert_eq(Combat.noise_radius("scrap_shotgun"), Combat.NOISE_GUNSHOT)
	assert_true(Combat.NOISE_GUNSHOT > Combat.NOISE_QUIET_RANGED * 3.0, "a gunshot carries much further")


func test_pellets_spread_symmetrically() -> void:
	var one := Combat.pellet_directions(Vector2.RIGHT, 1, 30.0)
	assert_eq(one.size(), 1)
	var five := Combat.pellet_directions(Vector2.RIGHT, 5, 28.0)
	assert_eq(five.size(), 5)
	assert_true(_near(five[2].angle(), 0.0, 0.001), "middle pellet straight ahead")
	assert_true(_near(five[0].angle(), -five[4].angle(), 0.001), "outer pellets mirror")
	assert_true(_near(rad_to_deg(five[4].angle()), 14.0, 0.01), "half the spread each side")


func test_segment_hits_circle() -> void:
	assert_true(Combat.segment_hits_circle(Vector2(0, 0), Vector2(20, 0), Vector2(10, 3), 4.0))
	assert_false(Combat.segment_hits_circle(Vector2(0, 0), Vector2(20, 0), Vector2(10, 6), 4.0))
	assert_false(Combat.segment_hits_circle(Vector2(0, 0), Vector2(20, 0), Vector2(30, 0), 4.0), "past the end")
	assert_true(Combat.segment_hits_circle(Vector2(5, 5), Vector2(5, 5), Vector2(6, 5), 2.0), "zero-length step")


func test_kill_xp_scales_with_depth() -> void:
	assert_eq(Combat.kill_xp(8, 1), 8)
	assert_eq(Combat.kill_xp(8, 3), 12)
	assert_eq(Combat.kill_xp(0, 1), 1, "always at least 1")


func test_every_weapon_has_usable_stats() -> void:
	for id in ItemDB.all_items():
		if not ItemDB.is_weapon(String(id)):
			continue
		var item := ItemDB.get_item(String(id))
		assert_true(int(item.get("damage", 0)) > 0, "%s damage" % id)
		assert_true(float(item.get("cooldown", 0.0)) > 0.0, "%s cooldown" % id)
		if String(item.get("weapon_class", "")) == "ranged":
			var ammo := String(item.get("ammo_item", ""))
			assert_true(ItemDB.has_item(ammo), "%s fires a real item (%s)" % [id, ammo])
			assert_true(float(item.get("projectile_speed", 0)) > 0.0, "%s projectile speed" % id)
		else:
			assert_true(float(item.get("reach", 0)) >= 12.0, "%s reach" % id)


## -- Radiation --

func test_radiation_ceiling_and_clamp() -> void:
	assert_eq(Radiation.ceiling_factor(0.0), 1.0)
	assert_true(_near(Radiation.ceiling_factor(Radiation.MAX_RADS), 0.5), "half at max")
	assert_eq(Radiation.effective_max(100.0, 0.0), 100.0)
	assert_eq(Radiation.effective_max(100.0, 100.0), 75.0)
	assert_eq(Radiation.clamp_rads(-5.0), 0.0)
	assert_eq(Radiation.clamp_rads(999.0), Radiation.MAX_RADS)


func test_radiation_resist_falloff_and_sleep() -> void:
	assert_true(_near(Radiation.absorbed(10.0, 0.3), 7.0))
	assert_true(_near(Radiation.absorbed(10.0, 2.0), 1.0), "resistance caps at 90%")
	assert_eq(Radiation.absorbed(-3.0, 0.0), 0.0)
	assert_true(_near(Radiation.source_rate(4.0, 0.0, 20.0), 4.0))
	assert_true(_near(Radiation.source_rate(4.0, 10.0, 20.0), 2.0))
	assert_eq(Radiation.source_rate(4.0, 25.0, 20.0), 0.0)
	assert_eq(Radiation.after_sleep(10.0), 0.0)
	assert_eq(Radiation.after_sleep(100.0), 100.0 - Radiation.SLEEP_RECOVERY)


func test_radiation_ambient_by_depth_and_storm() -> void:
	assert_eq(Radiation.ambient_rate(0, false), 0.0, "home is clean")
	assert_eq(Radiation.ambient_rate(1, false), 0.0, "the outskirts are clean")
	assert_true(Radiation.ambient_rate(3, false) > Radiation.ambient_rate(2, false), "deeper is hotter")
	assert_eq(Radiation.ambient_rate(9, false), Radiation.AMBIENT_BY_DEPTH[-1], "deep levels repeat the last")
	assert_true(Radiation.ambient_rate(1, true) >= Radiation.RADSTORM_FLOOR, "a radstorm bites even at depth 1")
	assert_eq(Radiation.status_text(10.0), "")
	assert_eq(Radiation.status_text(Radiation.WARN_AT), "Irradiated")
	assert_eq(Radiation.status_text(Radiation.SICKNESS_AT), "Radiation sick")


## -- Enemy catalogue --

func test_enemy_catalogue_is_complete() -> void:
	for id in ["shambler", "runner", "bloater", "rad_hound", "raider"]:
		var e := EnemyDB.get_enemy(id)
		assert_false(e.is_empty(), "%s exists" % id)
		assert_true(int(e["hp"]) > 0 and int(e["damage"]) > 0, "%s hp/damage" % id)
		assert_true(float(e["windup"]) >= 0.25, "%s has a readable telegraph" % id)
		assert_true(["melee", "lunge", "explode", "ranged"].has(String(e["attack"])), "%s attack style" % id)
		assert_true(float(e["sight"]) > float(e["attack_range"]) or String(e["attack"]) == "ranged",
			"%s sees before it reaches" % id)
	assert_true(EnemyDB.get_enemy("nope").is_empty())


func test_enemy_speeds_against_the_player() -> void:
	# The player walks at 56 px/s: shamblers can be outwalked, runners nearly match, hounds can't
	# be outrun (they must be fought).
	assert_true(float(EnemyDB.get_enemy("shambler")["chase_speed"]) < 56.0 * 0.6)
	assert_true(float(EnemyDB.get_enemy("runner")["chase_speed"]) < 56.0)
	assert_true(float(EnemyDB.get_enemy("rad_hound")["chase_speed"]) > 56.0)


func test_enemy_frame_index_maps_the_sheet() -> void:
	assert_eq(EnemyDB.frame_index("idle", "south", 0), 0)
	assert_eq(EnemyDB.frame_index("idle", "west", 3), 3 * 4 + 1, "idle wraps on 2 frames")
	assert_eq(EnemyDB.frame_index("walk", "north", 2), 5 * 4 + 2)
	assert_eq(EnemyDB.frame_index("attack", "east", 1), 10 * 4 + 1, "the telegraph frame")
	assert_eq(EnemyDB.frame_index("attack", "east", 9), 10 * 4 + 3, "clamped")
	assert_eq(EnemyDB.frame_index("hurt", "west", 0), 12 * 4 + 3)
	assert_eq(EnemyDB.frame_index("death", "south", 7), 13 * 4 + 3, "the corpse frame")
	assert_eq(EnemyDB.facing_for(Vector2(3, 1), "south"), "east")
	assert_eq(EnemyDB.facing_for(Vector2(-1, -4), "south"), "north")
	assert_eq(EnemyDB.facing_for(Vector2.ZERO, "west"), "west")
