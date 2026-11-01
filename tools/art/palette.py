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


# -- Enemies / combat FX (added by tools/art/enemies/, Milestone C) ------------------------------
# Ruins-side only (GDD §5/§9: the infected and raiders never appear in town). Ramps run darkest ->
# lightest like the ones above. Gore stays on the shared BLOOD ramp; these are its dried/dark kin.
INFECTED_SHIRT_RAMP = ["#2c3340", "#465062", "#64707f", "#848f9c"]   # shambler's faded work shirt
INFECTED_TROUSER_RAMP = ["#2a2620", "#423b30", "#5e5545"]             # grimy grey-brown trousers
INFECTED_HAIR = "#26241f"      # matted dark hair / scalp shadow on the infected
INFECTED_EYE = "#dcdcb2"       # milky eye glint of the infected (reads as "not human" at 1x)
GORE_DARK = "#3a1210"          # open maws, deep wounds (darker than BLOOD[0])
GORE_STAIN = "#6a2018"         # dried blood soaked into cloth (desaturated BLOOD[0])
FILTH = "#4a4030"              # grime smears on clothes
RUNNER_SKIN_RAMP = ["#3c4240", "#5f6764", "#8a918b", "#b0b4a8", "#cfd0c2"]  # runner: pallid, starved grey-white
RAIDER_LEATHER_RAMP = ["#2e231d", "#47362c", "#62493b", "#7e604d"]  # raider's scavenged leather vest
RAIDER_RED_RAMP = ["#4e1a14", "#7e2a1e", "#a83a26", "#c4583a"]      # raider rust-red bandana / wraps
RAIDER_TROUSER_RAMP = ["#232428", "#35373c", "#4b4d52"]             # raider's charcoal work trousers
RAIDER_HAIR = "#211a16"        # raider mohawk (near-black brown)
BLOATER_SKIN_RAMP = ["#34361a", "#545626", "#7c7c34", "#a29e46", "#c4bc68"]  # bloater: sickly swollen yellow-green
ICHOR_RAMP = ["#232c0e", "#3a4c14", "#5a741c", "#82a028", "#aac846"]  # bloater ichor / irradiated gore (ground stains, sprays)
RAD_HOT = "#d6ffa0"            # white-hot core of a rad glow (bloater about to burst) - hazard accent only
HOUND_FUR_RAMP = ["#2a2420", "#433830", "#5e4f40", "#796751", "#958267"]  # rad-hound: mangy ash-brown fur
HOUND_SKIN_RAMP = ["#5e3b38", "#87554f", "#ad7568"]  # rad-hound: raw bald patches, tongue
FX_WHITE = "#fff7dc"           # hottest core of slashes, tracers, muzzle flashes, sparks (warm, never pure white)
ALERT_RAMP = ["#8e2016", "#c43020", "#e84030", "#ff8a4a"]  # "!" alert mark over an enemy that spots you
BLOOD_STAIN_RAMP = ["#341411", "#4c1c17", "#64251c", "#7c3022"]  # blood decals on the ground (desaturated BLOOD)
HEART_HIGHLIGHT = "#ff9c80"    # HUD heart highlight (warm, on BLOOD[2])


# -- Ruined city kit (added by tools/art/ruins_city/, Milestone C) -------------------------------
# Building masses, ruin walls, landmarks and the ruins base ground. Ruins-side only, never
# seasonally modulated (GDD §9). Ramps run darkest -> lightest; all sit between the locked ruins
# colours (concrete / ash / rust / signage cream) so the city stays desaturated next to the town.
RUIN_BRICK_RAMP = ["#2b1d1a", "#432a23", "#5a382c", "#6e4636", "#825742", "#956a51"]  # weathered red-brown brick: ruin walls, shopfront
RUIN_BRICK_DARK_RAMP = ["#221c1a", "#332925", "#443630", "#55453b", "#675548", "#7a6757"]  # sooty umber brick: apartment block
RUIN_STONE_TRIM_RAMP = ["#4f4b42", "#666155", "#7d7768", "#948d7c", "#aaa28f"]  # pale cast-stone lintels, sills, cornices
RUIN_SIDING_RAMP = ["#262e30", "#354043", "#475457", "#5b686a", "#717d7c", "#8a9490"]  # faded blue-grey clapboard paint (house)
RUIN_SHINGLE_RAMP = ["#211b19", "#2e2522", "#3c302b", "#4b3c35", "#5b4a41", "#6c5a4e"]  # weathered brown asphalt shingles
RUIN_BLOCK_RAMP = ["#4c4a43", "#625f56", "#79766b", "#8f8b7f", "#a29e90", "#b5b0a0"]  # faded off-white painted block (garage)
RUIN_GLASS_RAMP = ["#161c1f", "#1f292c", "#2a373a", "#3b4b4e", "#566a6c", "#8199a0"]  # tinted window glass, dark -> sky glint
RUIN_VINE_RAMP = ["#2a271d", "#3b3628", "#4e4733", "#635a40"]  # dead climbing vines
RUIN_WEED_RAMP = ["#2d3324", "#3f4730", "#535c3b", "#6a7148"]  # dull olive weeds in cracks (NOT rad glow)
RUIN_DRYGRASS_RAMP = ["#4d4536", "#665c48", "#7f735a", "#998c6e"]  # dead straw-grey grass
RUIN_GROUND_RAMP = ["#3b342c", "#463f36", "#514940", "#5c5347", "#675d50", "#73685a"]  # ash-brown dirt base ground, [3] = ASH_BROWN
CHAR_RAMP = ["#171615", "#211f1d", "#2c2926", "#3a3632", "#4a4540", "#5d5750"]  # burnt-out metal / charred wood
ASH_PALE = "#8d877b"           # pale ash deposits on burnt things
PAPER_RAMP = ["#6e6754", "#8e866e", "#b5a98c", "#cfc5a8"]  # old paper / files ([2] = SIGNAGE_CREAM)
BONE_RAMP = ["#3e3a31", "#5c5649", "#7f7764", "#9e957d", "#b5a98c"]  # weathered bone, somber ([4] = SIGNAGE_CREAM)
TRUCK_PAINT_RAMP = ["#3a2a1a", "#574026", "#765834", "#937044", "#ad8957", "#c4a26c"]  # Kael's pickup: faded, cared-for sand-amber
TRANSIT_SIGN_RAMP = ["#1d2531", "#283446", "#36465c", "#4a5d74"]  # faded enamel transit-blue (subway sign)


# -- Townsfolk and Town Works (added by tools/art/townsfolk/, Milestone B) ------------------------
# Settlement side: warm outline, warm shadows, never seasonally modulated. Ramps run darkest ->
# lightest. The three code-drawn townsfolk (Brask, Wren, Doc Ama) stand next to the PixelLab
# four (art/characters/), so skin and cloth sit in the same peach / dusty band as theirs.
SKIN_RUDDY_RAMP = ["#6a3a2e", "#9a5a48", "#c47a64", "#dc957c", "#eeb299"]   # Brask: weathered, sun-reddened peach
SKIN_FAIR_RAMP = ["#6e4034", "#a0604e", "#cf8a72", "#eaab92", "#f8c9b0"]    # Wren: fair peach
SKIN_DEEP_RAMP = ["#3c231a", "#5a3524", "#7a4a31", "#9a6242", "#b67d57"]    # Doc Ama: deep brown
STEEL_HAIR_RAMP = ["#3e3b37", "#5f5b55", "#827d75", "#a6a197", "#c6c1b5"]   # Brask's grey crew cut (darker than Harlan's white)
AUBURN_RAMP = ["#4a1c12", "#76301c", "#a24526", "#c45f32", "#dd8048"]       # Wren's auburn hair
INK_HAIR_RAMP = ["#1d1613", "#2d231e", "#3f322b", "#54463d"]                 # Doc Ama's near-black hair
GREY_STREAK_RAMP = ["#8f8a82", "#b9b4aa"]                                    # grey streaks in Doc Ama's hair
OLIVE_DRAB_RAMP = ["#24271a", "#363b25", "#4a5131", "#5f673d", "#77804c", "#929a62"]  # Brask's ex-militia long coat
CHARCOAL_RAMP = ["#1f1c1a", "#2f2b28", "#423d38", "#57514a"]                 # Brask's trousers
SLATE_CLOTH_RAMP = ["#22252c", "#33373f", "#464b55", "#5b616b"]              # Doc Ama's trousers
KHAKI_RAMP = ["#3e3628", "#5a4f3a", "#7a6c4f", "#998a66", "#b5a780"]         # Wren's patched trousers
HOOD_BROWN_RAMP = ["#2e1f16", "#46301f", "#62442b", "#7d5a39", "#987249"]    # Wren's patched hood / jacket
WREN_JACKET_RAMP = ["#2a1820", "#3f2431", "#573443", "#704657", "#8a5c6c"]  # Wren's faded plum jacket (teal scarf sits on it as a complement)
SCARF_TEAL_RAMP = ["#20393a", "#2f5452", "#43726c", "#5f9288", "#84b3a4"]    # Wren's muted teal scarf (her accent)
COAT_WHITE_RAMP = ["#5e574c", "#8c8474", "#b4ab98", "#d6ceb9", "#ece5d2", "#f7f2e4"]  # Doc's off-white coat (warm, never pure white)
MEDIC_RED_RAMP = ["#5c1612", "#8e221c", "#bb3226", "#d84a36", "#ec7058"]     # red cross: armband, clinic sign, tent flag
LEATHER_RAMP = ["#2e1c12", "#4a2e1c", "#6a4428", "#8a5c36", "#a87648"]       # belts, straps, satchels, gloves
BOOT_RAMP = ["#1c1410", "#2e2119", "#433126", "#5c4535"]                     # townsfolk boots
BRASS_RAMP = ["#4a3614", "#7a5a20", "#ad8530", "#d4aa48", "#f0d07a"]         # buckles, goggles, lantern and sign fittings
LENS_GLINT = "#e4f0ea"         # spectacle / goggle lens catching the light (pale, cool)
EYE_DARK = "#24160c"           # townsfolk eyes (warm near-black, a hair lighter than OUTLINE_WARM)
SCAR_PALE = "#f2c4ae"          # Brask's old eyebrow scar
# Town Works buildings (clinic, expanded store, watchtower, greenhouse) and Doc's tent
WHITEWASH_RAMP = ["#62523f", "#94806a", "#bfae92", "#ddcfb2", "#f0e6cc"]     # clinic's whitewashed boards (wood shows where worn)
STORE_WOOD_RAMP = ["#1e0810", "#30151c", "#43201f", "#5b2a22", "#723526", "#8c4630"]  # Marta's store: dark wine-brown boards (sampled from store.png)
STORE_TAN_RAMP = ["#7c5040", "#9b6950", "#b98058", "#d6985f", "#ebae6e"]     # Marta's store: tan trim band (sampled from store.png)
WINDOW_GLOW_RAMP = ["#a8601c", "#e1982a", "#ffc948", "#ffe48a", "#fff4c8"]   # lit window glass: amber edge -> lamplight -> hot core
WINDOW_DARK_RAMP = ["#1c1a1e", "#2a2a30", "#3c4048", "#5a6670"]              # unlit / boarded-behind window glass
GREENHOUSE_GLASS_RAMP = ["#4f7f7a", "#76a8a0", "#a3cfc4", "#cfeee6"]         # greenhouse panes (drawn at alpha ~120-170)
GLASS_STREAK = "#f6fffb"       # white highlight streaks on glass (drawn at alpha ~190-220)
TENT_CANVAS_RAMP = ["#5a5038", "#7e7252", "#a39470", "#c4b68e", "#ddd0a8"]   # Doc's field tent: sun-faded army canvas
GH_FRAME_RAMP = ["#4a463e", "#6e695e", "#a39d8d", "#cfc9b6", "#ebe6d4"]    # greenhouse frame: light painted steel
GH_BRICK_RAMP = ["#4a2a1e", "#6e3c2a", "#8e5038", "#ab6748", "#c4825e"]    # greenhouse brick plinth (warm settlement brick)
