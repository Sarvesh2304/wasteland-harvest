extends Node
## Phase 7 Stage 3: per-NPC relationship/affinity state (ROADMAP.md Phase 7's "Relationship/
## affinity system — 0-10 per NPC, up via talk/gifts/quests ... gates dialogue and story events").
##
## One instance lives directly under Main (scenes/main.tscn), NOT per-zone — relationships are a
## settlement-wide concept, exactly like scripts/settlers.gd's roster and scripts/animals.gd's
## livestock, and the same "owned by Main, save-state lives here" shape as both. Unlike those two
## it connects to nothing and ticks nothing: affinity only ever changes because the player did
## something (talked this stage; gifts are Stage 4), so there is no _ready() day hook here.
##
## ## Stored state
##   _affinity:        {npc_id: int}  — the relationship value itself, always clamped 0-10.
##   _last_talked_day: {npc_id: int}  — the in-game day each NPC last awarded a talk tick, so
##                                      re-opening the same conversation five times in one day
##                                      can't farm points. Exactly the shape/purpose of
##                                      animals.gd's per-animal `last_care_day` (store the day,
##                                      compare against the current one — no per-day reset pass
##                                      to forget, and it survives a save/load unchanged).
## Both round-trip through the additive "affinity" save section (save_data.gd's encode_affinity/
## decode_affinity). An NPC absent from either dict reads as 0 / "never talked", so no entry has
## to be pre-created and an old save decodes into an empty, valid state.
##
## ## Scope: only the 4 named NPCs earn affinity
## Same scope decision Stage 1 (personality tags) and Stage 2 (schedules) made: Mayor Harlan,
## Marta, Scout Kael and Rancher Silas are authored characters; settlers (procedurally named,
## player-recruited via Phase 8's arrival system) are interchangeable by design and deliberately
## have no relationship track. The gate lives in the AWARD path (try_award_talk below, and
## Stage 4's gift award) rather than in adjust()/value_for(), which stay raw, unopinionated
## accessors — a quest or story beat that ever needs to move a non-named NPC's number can, but no
## routine player action will.

## Emitted whenever a stored value actually changes (never on a no-op clamp at 0 or 10, so a
## listener can treat every emission as a real relationship change). Nothing consumes this yet;
## Stage 5's context-sensitive dialogue and any future "hearts" HUD widget are its intended
## readers, and it exists now so those don't have to poll.
signal affinity_changed(npc_id: String, value: int)

const SaveData := preload("res://scripts/save_data.gd")

const MIN_AFFINITY := 0
const MAX_AFFINITY := 10

## One point per NPC per day for a real conversation. Deliberately small: 0-10 over a cozy
## multi-season game is a slow-build track (Stardew's own hearts take in-game months), and gifts
## (Stage 4) are meant to be the faster lever, so talking alone must not saturate it in a fortnight.
const TALK_AFFINITY_DELTA := 1

## The 4 authored, named NPCs — the exact id set layout_common.gd's TOWN_NPCS + RANCH_NPCS
## declares (pinned against those arrays by tests/test_affinity.gd so this copy can't drift).
## Held as a plain const here rather than derived from the layout data at runtime because this
## node has no other reason to depend on map layouts, and because Stage 4's gift award needs the
## same list.
const NAMED_NPC_IDS: Array[String] = [
	"mayor_harlan",
	"marta",
	"scout_kael",
	"rancher_silas",
]

## Tier thresholds (inclusive lower bounds on the 0-10 value). Stage 5 selects dialogue by TIER,
## never by the raw int, so these buckets — not the numbers — are the authoring contract:
##   0-1  "stranger"      — first meeting / barely spoken
##   2-4  "acquaintance"  — a familiar face
##   5-7  "friend"        — the tier Stage 5 gates its warmer greetings + gated choices on
##   8-10 "close"         — the top of the track, reachable only with sustained talk AND gifts
## Four tiers rather than Stardew's ten hearts because 11 discrete values don't support ten
## meaningfully distinct authored voices; four give each tier real content room.
const TIER_STRANGER := "stranger"
const TIER_ACQUAINTANCE := "acquaintance"
const TIER_FRIEND := "friend"
const TIER_CLOSE := "close"

const TIER_ACQUAINTANCE_MIN := 2
const TIER_FRIEND_MIN := 5
const TIER_CLOSE_MIN := 8

var _affinity: Dictionary = {}
var _last_talked_day: Dictionary = {}


## -- Pure helpers (static: headless-testable with no node, same convention as settlers.gd's
## roll rules) --

## Whether `npc_id` is one of the 4 authored NPCs that can earn affinity at all (see class doc).
static func is_named_npc(npc_id: String) -> bool:
	return npc_id in NAMED_NPC_IDS


## The tier name for a raw value — pure bucketing, see the threshold table in the class doc.
## Out-of-range input is clamped rather than rejected, so this is total over every int.
static func tier_for_value(value: int) -> String:
	var clamped := clampi(value, MIN_AFFINITY, MAX_AFFINITY)
	if clamped >= TIER_CLOSE_MIN:
		return TIER_CLOSE
	if clamped >= TIER_FRIEND_MIN:
		return TIER_FRIEND
	if clamped >= TIER_ACQUAINTANCE_MIN:
		return TIER_ACQUAINTANCE
	return TIER_STRANGER


## -- Live state --

## The stored relationship value, 0 for any NPC never interacted with (and for unknown ids).
func value_for(npc_id: String) -> int:
	return int(_affinity.get(npc_id, 0))


func tier_for(npc_id: String) -> String:
	return tier_for_value(value_for(npc_id))


## Moves an NPC's value by `delta`, clamped into 0-10. A no-op delta (0, or a push against a
## boundary the value already sits on) writes nothing at all — it neither emits affinity_changed
## nor creates a 0 entry that would then be serialised for an NPC nothing ever happened with.
## Intentionally NOT gated to the named NPCs — see the class doc's scope note; the gate lives in
## the award paths (try_award_talk here, Stage 4's gift award), so a future quest or story beat
## can still move any NPC's number deliberately.
func adjust(npc_id: String, delta: int) -> void:
	var before := value_for(npc_id)
	var after := clampi(before + delta, MIN_AFFINITY, MAX_AFFINITY)
	if after == before:
		return
	_affinity[npc_id] = after
	affinity_changed.emit(npc_id, after)


## The in-game day `npc_id` last awarded a talk tick, or -1 if it never has (never 0: day 0 is
## not a real day, but -1 makes "never" unambiguous against any legitimate day value).
func last_talked_day(npc_id: String) -> int:
	return int(_last_talked_day.get(npc_id, -1))


## The talk tick: called by scripts/dialogue_ui.gd when a REAL conversation opens (its
## _open_dialogue_at's award_affinity path — scripted beats like the Day-28 food shortage and
## Silas's "not_yet" store branch deliberately don't award). Returns true only when a point was
## actually granted, so a caller/test can tell "awarded" from "already talked today".
##
## Two gates, both required: the NPC must be one of the 4 named ones, and must not already have
## talked today (the last_talked_day dict — see class doc). The day stamp is only written when
## the award actually happens, so a non-named NPC never accumulates bookkeeping either.
func try_award_talk(npc_id: String, day: int) -> bool:
	if not is_named_npc(npc_id):
		return false
	if last_talked_day(npc_id) == day:
		return false
	_last_talked_day[npc_id] = day
	adjust(npc_id, TALK_AFFINITY_DELTA)
	return true


## -- Save/load (scripts/save_data.gd's encode_affinity/decode_affinity) --

func save_state() -> Dictionary:
	return SaveData.encode_affinity(_affinity, _last_talked_day)


## Restores both dicts from the additive "affinity" save section. An old save with no such
## section decodes to two empty dicts (decode_affinity's .get() defaults), i.e. a fresh
## relationship track — the same backward-compatible shape every other additive section here uses.
## Values are re-clamped into 0-10 on the way in: save_data.gd is the pure serialisation layer and
## deliberately knows nothing about this system's range, so the invariant is re-established here
## (a hand-edited or future-format save can never leave a stored value outside the tier table).
func load_state(data: Dictionary) -> void:
	var decoded := SaveData.decode_affinity(data)
	_affinity = {}
	for npc_id in decoded["values"]:
		_affinity[npc_id] = clampi(int(decoded["values"][npc_id]), MIN_AFFINITY, MAX_AFFINITY)
	_last_talked_day = decoded["last_talked_day"]
