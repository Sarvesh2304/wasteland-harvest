extends RefCounted
## Pure combat rules (Milestone C, 2026-10-07), unit tested in tests/test_combat.gd. No nodes,
## no autoloads: scripts/player.gd, scripts/enemy.gd, scripts/enemies.gd and
## scripts/projectile.gd call these so every number lives in one place.
##
## The design goals from GDD.md §5: melee stays relevant at every stage (it's quiet and free),
## guns are for when things go wrong (they're loud and every shot costs ammo), and a hit always
## *feels* like a hit (knockback, flash, numbers, a stagger that interrupts most windups).

const ItemDB := preload("res://scripts/item_db.gd")

## Total angle of a melee swing, centred on the aim direction.
const MELEE_ARC_DEGREES := 150.0
## A target this close is always hit, whatever the angle (hugging a zombie).
const POINT_BLANK := 6.0
## Seconds of invulnerability after the player is hit.
const PLAYER_IFRAMES := 0.9
## The player's knockback weight (enemies use their own data's weight).
const PLAYER_WEIGHT := 1.6
## Damage roll spread and crits.
const DAMAGE_SPREAD := 0.15
const CRIT_CHANCE := 0.08
const CRIT_MULTIPLIER := 1.5
## Combat skill (scripts/skills.gd "Hit harder, hurt less"): per level.
const SKILL_DAMAGE_BONUS := 0.04
const SKILL_DEFENSE_BONUS := 0.02
## How far noise carries, px. Enemies inside it come to investigate.
const NOISE_MELEE := 44.0
const NOISE_QUIET_RANGED := 56.0   # crossbow, slingshot
const NOISE_GUNSHOT := 210.0
const QUIET_AMMO: Array[String] = ["crossbow_bolt", "stone"]
## Melee costs a little stamina per swing; firing costs none (it costs ammo).
const ENERGY_PER_SWING := 0.5
## Shots fly this far before dropping.
const PROJECTILE_RANGE := 220.0
## Chance a fired crossbow bolt survives to be picked back up.
const BOLT_RECOVERY_CHANCE := 0.6


## Whether a target at `target_pos` (body radius `target_radius`) is caught by a melee swing
## from `origin` aimed along `aim` with `reach` px.
static func in_melee_arc(origin: Vector2, aim: Vector2, reach: float, target_pos: Vector2,
		target_radius: float, arc_degrees: float = MELEE_ARC_DEGREES) -> bool:
	var to := target_pos - origin
	var dist := to.length()
	if dist > reach + target_radius:
		return false
	if dist <= POINT_BLANK + target_radius:
		return true
	if aim.length_squared() < 0.0001:
		return false
	return absf(rad_to_deg(aim.angle_to(to))) <= arc_degrees * 0.5


## Flat armour reduction; a real hit never drops below 1.
static func damage_after_armor(damage: int, armor: int) -> int:
	if damage <= 0:
		return 0
	return maxi(1, damage - maxi(armor, 0))


## A hit's damage: base +/- DAMAGE_SPREAD, scaled by the attacker's skill multiplier, with a
## CRIT_CHANCE crit. Returns {damage, crit}.
static func roll_damage(base: int, rng: RandomNumberGenerator, multiplier: float = 1.0,
		crit_chance: float = CRIT_CHANCE) -> Dictionary:
	var dmg := float(base) * multiplier * rng.randf_range(1.0 - DAMAGE_SPREAD, 1.0 + DAMAGE_SPREAD)
	var crit := rng.randf() < crit_chance
	if crit:
		dmg *= CRIT_MULTIPLIER
	return {"damage": maxi(1, int(round(dmg))), "crit": crit}


## Velocity a hit imparts: away from `from`, scaled down by the target's weight.
static func knockback_velocity(from: Vector2, to: Vector2, strength: float, weight: float) -> Vector2:
	var d := to - from
	if d.length_squared() < 0.0001:
		d = Vector2.DOWN
	return d.normalized() * strength / maxf(weight, 0.1)


static func skill_damage_multiplier(combat_level: int) -> float:
	return 1.0 + SKILL_DAMAGE_BONUS * clampi(combat_level, 0, 10)


static func skill_defense_multiplier(combat_level: int) -> float:
	return 1.0 - SKILL_DEFENSE_BONUS * clampi(combat_level, 0, 10)


## Damage the player actually takes from a raw hit: combat-skill defence, then armour.
static func player_damage_taken(raw: int, armor: int, combat_level: int) -> int:
	if raw <= 0:
		return 0
	var scaled := maxi(1, int(round(float(raw) * skill_defense_multiplier(combat_level))))
	return damage_after_armor(scaled, armor)


## How far the noise of using `weapon_id` carries.
static func noise_radius(weapon_id: String) -> float:
	var item := ItemDB.get_item(weapon_id)
	if String(item.get("weapon_class", "")) != "ranged":
		return NOISE_MELEE
	if QUIET_AMMO.has(String(item.get("ammo_item", ""))):
		return NOISE_QUIET_RANGED
	return NOISE_GUNSHOT


## Unit aim vectors for a shot of `pellets` spread evenly across `spread_degrees` around `aim`.
static func pellet_directions(aim: Vector2, pellets: int, spread_degrees: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := maxi(pellets, 1)
	var base := aim.normalized() if aim.length_squared() > 0.0001 else Vector2.RIGHT
	if n == 1:
		out.append(base)
		return out
	for i in n:
		var t := float(i) / float(n - 1) - 0.5
		out.append(base.rotated(deg_to_rad(spread_degrees * t)))
	return out


## Seconds a melee weapon locks the player for one swing (its cooldown, floored for sanity).
static func swing_seconds(weapon_id: String) -> float:
	return maxf(float(ItemDB.get_item(weapon_id).get("cooldown", 0.4)), 0.15)


## Whether a segment (a projectile's step) passes within `radius` of `point`.
static func segment_hits_circle(a: Vector2, b: Vector2, point: Vector2, radius: float) -> bool:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a.distance_to(point) <= radius
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_to(point) <= radius


## XP for a kill (the enemy's xp field, +25% per depth beyond the first).
static func kill_xp(base_xp: int, depth: int) -> int:
	return maxi(1, int(round(float(base_xp) * (1.0 + 0.25 * maxi(depth - 1, 0)))))
