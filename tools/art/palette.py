"""Shared palette for every Wasteland Harvest art generator (see docs/ART_STYLE.md).

Hex values come from GDD.md §9 (locked anchor, seasonal and ruins palettes) plus a small set of
supporting ramps that were missing from the GDD (water, skin, sky/night, generic materials).
Generators import from here so the whole game stays on one palette. Add new colours HERE, with a
comment saying what they are for, rather than inlining hex values in a generator.
"""


def hex_to_rgba(value: str, alpha: int = 255) -> tuple:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


# -- Settlement anchor palette (GDD §9) -- never seasonally modulated --------------------------
AMBER = "#e1982a"          # identity colour: dry grass, thatch, dust, sun-warmed surfaces
LAMPLIGHT = "#ffc948"      # window glow, lanterns, UI highlights
CREAM = "#ffedb1"          # worn paper, plaster, daylight highlights
FIELD_GREEN = "#95ac49"    # living crops/grass (faded green)
LEAF_GREEN = "#5d7d3a"     # canopies, shadowed foliage, mature crops
WOOD_LIGHT = "#b77c3e"     # planks, fences, dock boards
WOOD_DARK = "#7b5025"      # beams, frames, shadowed wood
SOIL = "#895a2e"           # farm plots, dirt paths
METAL = "#9d9180"          # corrugated roofs, tools, patches
OUTLINE_WARM = "#281a0b"   # settlement outline / deepest shadow (never pure black)

# -- Seasonal sets (GDD §9) -- organic layer only ----------------------------------------------
SPRING = {
    "green": "#6cb34d",      # fresh rain-fed green
    "moss": "#488c55",       # damp moss green
    "soil_wet": "#6a4626",   # wet soil (dark, rich)
    "sky": "#7fa1b7",        # rain-sky blue-grey
    "blossom": "#f3acb7",    # mutant blossom pink
}
SUMMER = {
    "amber": "#f3b751",      # bleached amber
    "haze": "#ffe494",       # heat-haze cream
    "straw": "#bca843",      # sun-scorched straw green
    "earth": "#af6d2c",      # baked earth
    "sky": "#e8d6a6",        # washed haze sky
}
AUTUMN = {
    "amber": "#e88b0f",      # peak amber
    "gold": "#ffb72d",       # harvest gold
    "rust": "#c5520f",       # rust-leaf orange
    "ember": "#a03c13",      # ember red-brown
    "green": "#8c8832",      # last fading green
}
WINTER = {
    "snow": "#e0e4e3",       # snow-ash white
    "blue_grey": "#92a5b7",  # cold blue-grey
    "ground": "#686458",     # frozen ground
    "branch": "#78634c",     # dead-branch brown
    "slate": "#4b5c6c",      # winter-sky slate
}

# -- Ruins palette (GDD §9) -- never seasonally modulated ---------------------------------------
CONCRETE_LIGHT = "#6f6f68"
CONCRETE_DARK = "#4a4a44"
ASH_BROWN = "#5c5347"
RUST_DULL = "#7d452a"
RUST_BRIGHT = "#a65c30"
SIGNAGE_CREAM = "#b5a98c"
RAD_GLOW = "#86e83e"       # ACCENT ONLY — always means hazard
RAD_GLOW_DEEP = "#3fa832"
OUTLINE_COLD = "#181a16"   # ruins outline

# -- Shared gore ramp (shared-assets rule; ruins/combat only) -----------------------------------
BLOOD = ["#9b1818", "#c43020", "#e84030"]

# -- Supporting ramps (added 2026-10-07; not in the GDD tables) --------------------------------
# Ramps run darkest -> lightest. Use them for shading so hue-shifting stays consistent.
GRASS_SPRING_RAMP = ["#2f5a35", "#488c55", "#5b9f4c", "#6cb34d", "#8cc75a", "#b2d96a"]
GRASS_SUMMER_RAMP = ["#5b5a24", "#7e7a2e", "#9e9638", "#bca843", "#d4c060", "#ead68a"]
GRASS_AUTUMN_RAMP = ["#4f3a14", "#6e5a1e", "#8c8832", "#a89a3c", "#c9a440", "#e4bf5a"]
GRASS_WINTER_RAMP = ["#4b5c6c", "#686458", "#92a5b7", "#b9c6cf", "#e0e4e3", "#f4f6f4"]
SOIL_RAMP = ["#3b2410", "#5a3a1c", "#6a4626", "#895a2e", "#a5703a", "#c28a4c"]
SOIL_WET_RAMP = ["#24160a", "#3a2412", "#4a2f18", "#5c3b1f", "#6a4626", "#7d5531"]
DIRT_RAMP = ["#4a3220", "#6b4a2c", "#8a6238", "#a87c48", "#c4995e", "#dcb77a"]
WATER_RAMP = ["#1d3b4f", "#2c5468", "#3c6f86", "#4f8aa1", "#6aa6b8", "#9cc8d2", "#d6ecee"]
STONE_RAMP = ["#3a3833", "#55524b", "#706b62", "#8d877c", "#aaa398", "#c9c3b6"]
WOOD_RAMP = ["#3d2612", "#5c3a1b", "#7b5025", "#9a6631", "#b77c3e", "#d39a58"]
BARK_RAMP = ["#2e1d10", "#463019", "#5e4124", "#78563a", "#937055"]
LEAF_RAMP = ["#22401f", "#33582a", "#4a7232", "#5d7d3a", "#7c9a45", "#a0b85a"]
METAL_RAMP = ["#3b3832", "#57524a", "#7a7266", "#9d9180", "#bcb2a0", "#ddd5c4"]
RUST_RAMP = ["#4a2516", "#6a331d", "#7d452a", "#a65c30", "#c47a45", "#d99a63"]
CLOTH_RAMP = ["#3b2b22", "#5a4334", "#7a5f49", "#9b7e64", "#bfa384"]
SKIN_RAMPS = [
    ["#5a3a28", "#7d5236", "#a06c48", "#c48a5e", "#dca77a"],
    ["#4a2c1c", "#6b3f27", "#8c5534", "#ad6e45", "#c98b5c"],
    ["#6e4a34", "#946649", "#b8845f", "#d6a47c", "#ecc29a"],
]
ZOMBIE_SKIN_RAMP = ["#2f3a2a", "#465540", "#5f6e55", "#7d8a6d", "#9aa585"]
NIGHT_SKY = "#1b2238"
FOAM = "#e9f4f2"


def season_grass_ramp(season: str) -> list:
    return {
        "spring": GRASS_SPRING_RAMP,
        "summer": GRASS_SUMMER_RAMP,
        "autumn": GRASS_AUTUMN_RAMP,
        "winter": GRASS_WINTER_RAMP,
    }[season]


SEASONS = ["spring", "summer", "autumn", "winter"]
