extends RefCounted
## Pure farming-plot logic (ROADMAP Phase 3): tillability, growth-stage advancement, watering/
## wilting, and harvest yield. No scene/node state lives here — scripts/test_map.gd owns the
## actual per-cell Dictionary storage and calls into these static functions, exactly the
## game_camera.gd / day_manager.gd convention of keeping rules pure and testable separate from
## the stateful node that applies them.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const FarmGrid := preload("res://scripts/farm_grid.gd")`.
##
## ## Dual-grid tilling semantics (the open question flagged at the end of Phase 2)
##
## The test map's ground is a *dual-grid* Wang sheet (scripts/wang_tileset.gd, scripts/
## test_map.gd): each visual tile is painted by sampling the boolean soil/grass state of the
## FOUR LOGICAL CELLS that meet at that visual tile's corners, not by looking up one cell's own
## terrain directly. That is the layer where "corners" matter — it is a rendering technique, not
## a gameplay grid.
##
## Interaction ("till the tile in front of you") targets exactly ONE LOGICAL CELL — the same
## cell coordinate space TestMapLayout already uses for terrain, collision, and the player's
## floor(position / 16) tile math. Tilling one cell just flips that cell's "is soil" bit in a
## runtime overlay (test_map.gd's `_tilled` dictionary); the existing corner-sampling ground
## painter then re-renders the (up to four) visual tiles whose corners touch that cell, which
## automatically blends the new soil patch into its grass neighbors with no farming-specific
## Wang logic required.
##
## Net effect, and why this is the right mapping rather than an accident of reuse: one till
## action = one gameplay-meaningful unit (a plantable plot), but it visually "blurs" outward
## half a tile in each direction because that is exactly what a dual-grid is for — hard square
## farm plots would look wrong against this art style. Cells are gameplay truth; corners are a
## pure rendering detail of how cells get drawn. Nothing about farming needed to know the corner
## math at all, which is the sign this is the correct layering.
##
## ## Watering / wilting rule (explicit judgment call, checklist didn't specify one)
##
## "Water crops daily or they die" is taken literally and without a grace mechanic: a planted,
## not-yet-mature crop that isn't watered before the next day_started tick wilts immediately —
## the plot clears back to bare tilled soil, no yield, no warning stage. This is stricter than
## vanilla Stardew (which merely pauses growth on a missed watering) but matches the checklist's
## actual wording, and it's simple to teach ("water it or lose it"). Once a crop reaches its
## final stage (mature/harvestable) it no longer needs water — it just waits to be harvested,
## since punishing the player for not immediately harvesting a finished crop would be needlessly
## cruel and isn't what "grow" implies.

## True for terrain characters a hoe can till: open grass and the player-spawn cell (grass
## underneath). Already-tilled farmland, plank floors, and rubble are not tillable.
static func is_tillable_terrain(cell_char: String) -> bool:
	return cell_char == "." or cell_char == "@"


## One watered day of growth. `plot` is {crop_id, stage, watered}; `growth_stages` is that
## crop's total stage count (CropDB.growth_stages). Returns the advanced plot, the same plot
## unchanged (already mature), or {} if the crop wilted — caller must then clear the cell back
## to bare tilled soil (see class doc above for the exact rule).
static func advance_plot(plot: Dictionary, growth_stages: int) -> Dictionary:
	if plot.is_empty() or String(plot.get("crop_id", "")) == "":
		return plot
	var stage: int = int(plot.get("stage", 0))
	if stage >= growth_stages - 1:
		return plot  # mature: holds indefinitely, no water needed, waits for harvest
	if not bool(plot.get("watered", false)):
		return {}  # wilted
	var next_plot: Dictionary = plot.duplicate()
	next_plot["stage"] = mini(stage + 1, growth_stages - 1)
	next_plot["watered"] = false
	return next_plot


static func is_mature(plot: Dictionary, growth_stages: int) -> bool:
	return not plot.is_empty() and String(plot.get("crop_id", "")) != "" \
		and int(plot.get("stage", 0)) >= growth_stages - 1


## {} if plot isn't ready to harvest, else {item_id, count} per the crop's yield definition.
static func harvest_yield(plot: Dictionary, crop_def: Dictionary) -> Dictionary:
	var growth_stages: int = int(crop_def.get("growth_stages", 1))
	if not is_mature(plot, growth_stages):
		return {}
	return {
		"item_id": String(crop_def.get("yield_item", "")),
		"count": int(crop_def.get("yield_quantity", 1)),
	}
