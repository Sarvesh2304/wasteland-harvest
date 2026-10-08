extends RefCounted
## The raider faction's view of the player (Milestone C, 2026-10-08; GDD.md §6), pure and unit
## tested (tests/test_faction.gd). Reputation runs -100..100 and starts at 0. Its bands:
##   Hostile: raiders shoot on sight.
##   Wary (the start): they warn you off and only fight if you push it.
##   Tolerated, Trusted: they hold off even at close range.
## Actions move it, not dialogue checkboxes:
##   - killing a raider costs a lot;
##   - starting a fight with a group costs a little;
##   - finishing a run without spilling raider blood earns a little back.
## Recoverable but slow, as the GDD asks. Trader access, faction jobs and safe passage hang off
## the same standing in later milestones.

const MIN_REP := -100
const MAX_REP := 100
const HOSTILE_BELOW := -30
const TOLERATED_FROM := 20
const TRUSTED_FROM := 60
const KILL_COST := 12
const PROVOKE_COST := 5
const PEACEFUL_RUN_GAIN := 3
## Wary raiders let you come this close (px) before they decide you mean trouble.
const WARY_PERSONAL_SPACE := 44.0
const TOLERATED_PERSONAL_SPACE := 20.0

## What a wary raider calls out when it spots you.
const WARNINGS: Array[String] = [
	"Turn around, farmer.",
	"This street's taken.",
	"Keep walking. Other way.",
	"Nothing here for you.",
	"Back off. Last warning.",
]


static func clamp_rep(rep: int) -> int:
	return clampi(rep, MIN_REP, MAX_REP)


static func standing(rep: int) -> String:
	if rep < HOSTILE_BELOW:
		return "Hostile"
	if rep < TOLERATED_FROM:
		return "Wary"
	if rep < TRUSTED_FROM:
		return "Tolerated"
	return "Trusted"


static func attacks_on_sight(rep: int) -> bool:
	return standing(rep) == "Hostile"


## How close the player may come before a non-hostile raider group turns on them.
static func personal_space(rep: int) -> float:
	match standing(rep):
		"Wary":
			return WARY_PERSONAL_SPACE
		"Tolerated":
			return TOLERATED_PERSONAL_SPACE
		"Trusted":
			return 0.0
	return INF


## Rep after an event: "kill", "provoke" or "peaceful_run".
static func after(rep: int, event: String) -> int:
	match event:
		"kill":
			return clamp_rep(rep - KILL_COST)
		"provoke":
			return clamp_rep(rep - PROVOKE_COST)
		"peaceful_run":
			return clamp_rep(rep + PEACEFUL_RUN_GAIN)
	return clamp_rep(rep)


## The message when standing crosses a band (or "" if it didn't).
static func change_message(before: int, now: int) -> String:
	var a := standing(before)
	var b := standing(now)
	if a == b:
		return ""
	match b:
		"Hostile":
			return "The raiders won't forget this. They'll shoot on sight now."
		"Wary":
			return "The raiders are watching you. Warily."
		"Tolerated":
			return "Word gets around: the raiders tolerate you."
		"Trusted":
			return "The raiders trust you. As much as they trust anyone."
	return ""
