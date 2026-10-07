"""Extra colours used only by the environment pipeline (supplements tools/art/palette.py).

Every value here is derived from / sits between the locked GDD §9 colours; ramps run darkest ->
lightest like palette.py's. Comment each entry with what it is for.
"""

# -- terrain ------------------------------------------------------------------------------------
SAND_RAMP = ["#7d6644", "#a08559", "#bea170", "#d6bb86", "#e6d3a2", "#f3e7c4"]   # riverbank sand
GRAVEL_RAMP = ["#4a443c", "#615a50", "#7a7266", "#948b7d", "#aea596", "#c8c0b0"]  # placed gravel
WET_SHEEN = "#8e7660"            # wet-soil ridge glint (desaturated, lighter than soil_wet top)
SNOW_SHADOW = "#c6d1d8"          # very soft snow-ripple shadow (between blue-grey and snow)
WINTER_GRASS_TIP = "#7b7d5a"     # dead grass tips poking through snow
WINTER_GRASS_TIP_DARK = "#5c5d44"

# ruins ground (desaturated, never seasonally modulated)
ASPHALT_RAMP = ["#232427", "#2b2c2e", "#333436", "#3c3d3d", "#474744", "#55554f"]
CONCRETE_RAMP = ["#3a3a35", "#4a4a44", "#5b5b55", "#6f6f68", "#7e7e76", "#8f8e85"]
PAINT_FADED_YELLOW = "#9e8b4f"   # worn lane paint
PAINT_FADED_CREAM = "#b5a98c"    # = SIGNAGE_CREAM, road markings
RUBBLE_BASE_RAMP = ["#2f2c28", "#3d3933", "#4b4740", "#5c5347", "#6b6357"]   # dusty debris ground

# -- foliage --------------------------------------------------------------------------------------
# Canopy ramps per season (darkest -> lightest). Deliberately darker/bluer than the grass of the
# same season so trees separate from the ground.
CANOPY_SPRING = ["#1d3524", "#264a2e", "#336437", "#457e3e", "#5e9a45", "#80b551", "#a6cc63"]
CANOPY_SUMMER = ["#28301a", "#38441e", "#4d5a24", "#66722c", "#848c36", "#a4a646", "#c2bf62"]
CANOPY_AUTUMN = ["#3e1f0e", "#6a2c10", "#94400f", "#bb5a12", "#dc7d16", "#f2a528", "#ffc65a"]
CANOPY_AUTUMN_GOLD = ["#5a3a10", "#86581a", "#b07f22", "#d6a12a", "#f0c042", "#ffdc78"]
BLOSSOM_RAMP = ["#9c4d63", "#cc7286", "#f3acb7", "#ffd6da"]
PINE_RAMP = ["#14271f", "#1c3529", "#244533", "#2f573d", "#3d6b47", "#528255", "#6c9a62"]
PINE_SUMMER_RAMP = ["#1c281f", "#283a2b", "#364b35", "#465d3f", "#5a704a", "#748656", "#929e68"]
PINE_AUTUMN_RAMP = ["#1a2418", "#24321f", "#2f4126", "#3d512c", "#575f2e", "#7c6e32", "#a0843e"]
SNOW_RAMP = ["#7b8b9b", "#9fb0bf", "#c3cfd8", "#e0e4e3", "#f4f6f4"]
BARK_RAMP_COOL = ["#2a1f18", "#3e2f24", "#54402f", "#6b543d", "#86704f"]   # weathered/dead wood
DEADWOOD_RAMP = ["#3a3330", "#524843", "#6c6058", "#887a6f", "#a3968a"]     # bleached snag
FLOWER_YELLOW = ["#b8801a", "#e8b030", "#ffd860"]
FLOWER_WHITE = ["#a8a090", "#ddd6c4", "#fff8e8"]
FLOWER_BLUE = ["#4a5a8c", "#6f86b8", "#a6bce0"]
FLOWER_RED = ["#7a2a22", "#b4452e", "#e07050"]

# -- materials ------------------------------------------------------------------------------------
RUBBER_RAMP = ["#1b1918", "#262321", "#33302c", "#45403a", "#5a544c"]        # tyres
GLASS_GREEN = ["#2c4a38", "#4a7458", "#7aa68a", "#c4e0cc"]                    # bottle glass
GLASS_BROWN = ["#3e2412", "#6a3c1c", "#985a2a", "#d49a5a"]
CAN_RAMP = ["#4a3a30", "#7d5a40", "#9a7a5a", "#c0a888"]                       # rusted tin
FIRE_RAMP = ["#7a1e0c", "#c2410f", "#ec7a1c", "#ffb72d", "#ffdf7a", "#fff4c8"]
EMBER = "#ff8a2a"
ROPE = ["#6a5232", "#9a7c4e", "#c4a46a"]
STRAW = ["#8a6a22", "#b88e2e", "#e1b84a", "#f5d77a"]                          # scarecrow / thatch
CANVAS_RAMP = ["#6a5a40", "#8e7c5a", "#b3a07a", "#d4c39c", "#ece0bc"]         # tarp/canvas
CLOTH_RED = ["#5e2420", "#8a3a2c", "#b0523a", "#cf7650"]                       # faded red cloth
CLOTH_TEAL = ["#24403e", "#355c58", "#4d7c74", "#6e9c8e"]                      # faded teal cloth
CLOTH_MUSTARD = ["#6a4a14", "#9a7022", "#c4962e", "#e0b84a"]                   # mustard cloth
CLOTH_BLUE = ["#2a3446", "#3e4c64", "#576a84", "#7a8ea6"]                      # denim
PAINT_GREEN = ["#2c3a26", "#3e5236", "#56704a", "#728c60"]                     # painted metal
SIGN_RED = ["#5a1e18", "#8a2e22", "#b34430"]

# ruins paints (faded, desaturated)
CAR_RED = ["#3a1c18", "#5a2c24", "#7a3f30", "#94553f", "#a8705a"]
CAR_BLUE = ["#1e2630", "#2c3844", "#3e4c58", "#55646e", "#6e7c84"]
CAR_CREAM = ["#4a4436", "#6a6250", "#8c826a", "#a89e84", "#c0b79c"]
BUS_YELLOW = ["#3e3218", "#5e4a20", "#7e6428", "#9c7e34", "#b49646"]
DUMPSTER_GREEN = ["#1c2620", "#26342a", "#334536", "#435844", "#566c54"]
CONE_ORANGE = ["#5a2410", "#8a3a16", "#b45220", "#d47236"]
HAZARD_YELLOW = ["#5a4a14", "#8a7020", "#b4942c"]
RAD_RAMP = ["#1f4a1a", "#2f7a26", "#3fa832", "#86e83e", "#c8ff8a"]           # rad glow ooze
LOCKER_GREY = ["#262a2c", "#363c3e", "#4a5254", "#5e6668", "#747c7c"]
FRIDGE_WHITE = ["#4a4a44", "#6a6a62", "#8c8a80", "#a8a598", "#c2bfb0"]
