extends Node
## Skills (2026-10-07, Milestone B): Farming, Foraging, Scavenging, Combat and Crafting.
##
## XP arrives on Events.xp_gained from whatever earned it (planting and harvesting, felling trees
## and clearing brush, breaking rock and scrap, fighting, crafting). Ten levels per skill on a
## Stardew-shaped curve. Each level makes that skill's tools cheaper to swing (5% less energy per
## level) and unlocks recipes (data/recipes.json "unlock"). Level-ups toast, chime and emit
## Events.skill_leveled. A child of Main; saved as the "skills" section.

const SKILLS: Array[String] = ["farming", "foraging", "scavenging", "combat", "crafting"]
const NAMES := {
	"farming": "Farming",
	"foraging": "Foraging",
	"scavenging": "Scavenging",
	"combat": "Combat",
	"crafting": "Crafting",
}
## What each skill's levels buy, shown on the Skills tab.
const PERK_TEXT := {
	"farming": "Cheaper hoe and can",
	"foraging": "Cheaper axe and scythe",
	"scavenging": "Cheaper pickaxe",
	"combat": "Hit harder, hurt less",
	"crafting": "Learn more recipes",
}
## Total XP needed to reach each level 1..10.
const LEVEL_XP: Array[int] = [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000]
const MAX_LEVEL := 10
const ENERGY_DISCOUNT_PER_LEVEL := 0.05
## Which skill governs each tool's energy cost.
const TOOL_SKILL := {
	"hoe": "farming",
	"watering_can": "farming",
	"axe": "foraging",
	"scythe": "foraging",
	"pickaxe": "scavenging",
}

signal changed

var xp: Dictionary = {}
## Milestone C: recipe ids learned from blueprints found in the ruins.
var blueprints: Array[String] = []


func _ready() -> void:
	for skill in SKILLS:
		xp[skill] = 0
	Events.xp_gained.connect(add_xp)


func add_xp(skill: String, amount: int) -> void:
	if not xp.has(skill) or amount <= 0:
		return
	var before := level(skill)
	xp[skill] = int(xp[skill]) + amount
	var after := level(skill)
	for new_level in range(before + 1, after + 1):
		Events.skill_leveled.emit(skill, new_level)
		Events.message.emit("%s level %d!" % [NAMES[skill], new_level])
		Audio.play_sfx("achievement", -2.0, 0.0)
	changed.emit()


func level(skill: String) -> int:
	return level_for_xp(int(xp.get(skill, 0)))


## Energy multiplier for swinging `tool_kind` (1.0 for tools no skill governs).
func energy_multiplier(tool_kind: String) -> float:
	var skill := String(TOOL_SKILL.get(tool_kind, ""))
	if skill == "":
		return 1.0
	return energy_multiplier_for_level(level(skill))


## -- Blueprints (Milestone C) --

func knows_blueprint(recipe_id: String) -> bool:
	return blueprints.has(recipe_id)


## Learns `recipe_id` (false if already known).
func learn_blueprint(recipe_id: String) -> bool:
	if recipe_id == "" or blueprints.has(recipe_id):
		return false
	blueprints.append(recipe_id)
	changed.emit()
	return true


## {skill: level} for every skill plus {"blueprint:<id>": 1} for every learned blueprint: what
## the crafting rules (recipe_db.gd is_unlocked) check recipes against.
func crafting_levels() -> Dictionary:
	var out := {}
	for skill in SKILLS:
		out[skill] = level(skill)
	for id in blueprints:
		out["blueprint:" + id] = 1
	return out


## -- Pure rules (unit tested) --

static func level_for_xp(total: int) -> int:
	var lvl := 0
	for threshold in LEVEL_XP:
		if total >= threshold:
			lvl += 1
		else:
			break
	return lvl


## Fraction of the way from the current level to the next (1.0 at max level).
static func progress_to_next(total: int) -> float:
	var lvl := level_for_xp(total)
	if lvl >= MAX_LEVEL:
		return 1.0
	var floor_xp := 0 if lvl == 0 else LEVEL_XP[lvl - 1]
	var ceiling_xp := LEVEL_XP[lvl]
	return clampf(float(total - floor_xp) / float(ceiling_xp - floor_xp), 0.0, 1.0)


static func energy_multiplier_for_level(lvl: int) -> float:
	return maxf(1.0 - ENERGY_DISCOUNT_PER_LEVEL * clampi(lvl, 0, MAX_LEVEL), 0.5)


## -- Save/load (the "skills" save section) --

func save_state() -> Dictionary:
	var out := xp.duplicate()
	out["_blueprints"] = blueprints.duplicate()
	return out


func load_state(data: Dictionary) -> void:
	for skill in SKILLS:
		xp[skill] = maxi(int(data.get(skill, 0)), 0)
	blueprints.clear()
	for id in data.get("_blueprints", []):
		blueprints.append(String(id))
	changed.emit()
