extends RefCounted
## Pure radiation rules (Milestone C, 2026-10-07; GDD.md §5 "Radiation"), unit tested in
## tests/test_radiation.gd. The player carries an exposure meter (0..MAX_RADS) that persists
## between days: it shrinks the HP and energy ceilings as it climbs, makes the player sick past
## SICKNESS_AT, and only falls with sleep (a little each night) or a Purifier. Sources: rad
## puddles and barrels in the ruins, deeper districts' background count, rad-hound bites,
## bursting bloaters, and radstorms on an expedition. Gear with rad_resist cuts what gets in.

const MAX_RADS := 200.0
## At MAX_RADS the HP/energy ceilings are down by this fraction.
const MAX_CEILING_LOSS := 0.5
## Past this the player feels it: a slow HP drain on expeditions (never below 1 HP).
const SICKNESS_AT := 150.0
const SICKNESS_HP_PER_SECOND := 0.25
## A night's sleep flushes this much.
const SLEEP_RECOVERY := 30.0
## Background count per second on an expedition, by depth (1-based; deeper repeats the last).
const AMBIENT_BY_DEPTH: Array[float] = [0.0, 0.02, 0.06, 0.1]
## A radstorm over the ruins multiplies the background count and adds a floor.
const RADSTORM_MULTIPLIER := 3.0
const RADSTORM_FLOOR := 0.15
## Rad sources fall off linearly to zero at this many px from their centre.
const SOURCE_RADIUS := 26.0
## Warning thresholds for the HUD/geiger.
const WARN_AT := 50.0


static func clamp_rads(rads: float) -> float:
	return clampf(rads, 0.0, MAX_RADS)


## The fraction of the normal HP/energy ceiling left at `rads`.
static func ceiling_factor(rads: float) -> float:
	return 1.0 - MAX_CEILING_LOSS * clamp_rads(rads) / MAX_RADS


## Max HP after radiation (never below 1).
static func effective_max(base_max: float, rads: float) -> float:
	return maxf(1.0, round(base_max * ceiling_factor(rads)))


## Exposure actually absorbed from `amount` with gear resistance `resist` (0..0.9).
static func absorbed(amount: float, resist: float) -> float:
	return maxf(amount, 0.0) * (1.0 - clampf(resist, 0.0, 0.9))


## A point source's rads/second at distance `dist` (linear falloff over SOURCE_RADIUS).
static func source_rate(strength: float, dist: float, radius: float = SOURCE_RADIUS) -> float:
	if dist >= radius:
		return 0.0
	return strength * (1.0 - dist / radius)


## Background rads/second on an expedition at `depth`, with a radstorm or not.
static func ambient_rate(depth: int, radstorm: bool) -> float:
	if depth <= 0:
		return 0.0
	var base := AMBIENT_BY_DEPTH[clampi(depth - 1, 0, AMBIENT_BY_DEPTH.size() - 1)]
	if radstorm:
		return maxf(base * RADSTORM_MULTIPLIER, RADSTORM_FLOOR)
	return base


## Rads after a night's sleep.
static func after_sleep(rads: float) -> float:
	return clamp_rads(rads - SLEEP_RECOVERY)


static func is_sick(rads: float) -> bool:
	return rads >= SICKNESS_AT


## "", "Irradiated" or "Radiation sick", for the HUD.
static func status_text(rads: float) -> String:
	if rads >= SICKNESS_AT:
		return "Radiation sick"
	if rads >= WARN_AT:
		return "Irradiated"
	return ""
