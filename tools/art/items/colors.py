"""Extra colour ramps for the item / crop art (tools/art/items).

Everything shared lives in tools/art/palette.py (imported here as P); this file only adds the
material ramps the item icons need on top of it. Every ramp runs darkest -> lightest and is
hue-shifted (shadows drift toward red-purple / cool, highlights toward warm yellow) per
docs/ART_STYLE.md section 2. Each entry says what it is for.
"""
import palette as P

# -- woods / plant fibre ------------------------------------------------------------------------
WOOD = P.WOOD_RAMP                                   # tool handles, crates, bowls (6 shades)
WOOD_DARK_POLISH = ["#24140c", "#3a2214", "#55321c", "#744628", "#94603a", "#b47c4e"]  # tier-4 handles, hardwood
HARDWOOD = ["#2a170c", "#432616", "#5e3820", "#7a4c2a", "#98643a", "#b47e4e"]   # dense old-growth log
END_GRAIN = ["#7b5025", "#a8743c", "#c8965a", "#e2b878", "#f4d49a"]            # cut log faces (light)
HARD_END = ["#4a2a16", "#6e4424", "#8e5c34", "#ac7848", "#c89462"]             # hardwood cut face
BAMBOO = ["#4e4418", "#76682a", "#a0903e", "#c6b45a", "#e4d482"]               # fishing rod
FIBER = ["#3c4a1c", "#5a6a26", "#7c8a34", "#a0a84a", "#c4c46a", "#e2dc94"]      # plant fibre bundle
STRAW = ["#5e4416", "#86621e", "#b08a2c", "#d4ae44", "#ecd070", "#fbe8a4"]      # wheat, reed, straw

# -- metals -------------------------------------------------------------------------------------
RUST = ["#3e1e12", "#5e2c18", "#7d452a", "#a65c30", "#c47a45", "#d99a63"]       # tier-1 rusty iron
RUST_PIT = "#4a2516"                                                          # rust pitting / dark flecks
IRON = ["#33302b", "#4c4740", "#6a6358", "#8c8476", "#aea594", "#d0c8b6"]       # tier-2 base, bolts, pipe
COPPER = ["#4a1c10", "#783418", "#a8522a", "#cf783c", "#eca25a", "#ffd08a"]     # tier-2 patches, wire, still
STEEL = ["#252b31", "#3d464e", "#5c6972", "#86939a", "#b2bec0", "#e4ecea"]      # tier-3 clean steel, blades
BLUE_STEEL = ["#18203a", "#26385e", "#3a5888", "#577eb2", "#86aed6", "#c8e4f6"] # tier-4 pre-war blue steel
GOLD = ["#5e3408", "#925c10", "#c8901c", "#f0bc34", "#ffdc6a", "#fff4c0"]       # tier-4 trim, saber guard
BRASS = ["#40300e", "#6c5418", "#9a7c26", "#c6a23c", "#e6c866", "#fbecaa"]      # ammo casings, fittings
LEAD = ["#2a2c34", "#40434e", "#5a5e6a", "#767b86", "#979ca4", "#bcc0c4"]       # lead scrap (blue-grey)
TIN = ["#3a3c3c", "#5a5c58", "#7e807a", "#a4a69c", "#c8c8bc", "#ecebdf"]        # cans, tins, lids
CHARCOAL = ["#121214", "#1e1d22", "#2c2a30", "#3e3b40", "#5a5558", "#80797a"]   # charcoal lumps
CONCRETE = ["#38382f", "#4a4a44", "#5d5d56", "#6f6f68", "#8a8a80", "#a8a69a"]   # rebar chunk, gravel

# -- paper, cloth, leather ----------------------------------------------------------------------
PAPER = ["#7a5a3a", "#a88a62", "#d2b88a", "#ead6a2", "#ffedb1"]               # seed packets (ends in CREAM)
PAPER_OLD = ["#6a4c2c", "#987446", "#c09a62", "#dcbc80", "#f0d89e"]           # lore notes, labels
BLUEPRINT = ["#122848", "#1c3e6e", "#2a5994", "#467cb8", "#86b2dc", "#d2ecfa"]  # blueprint paper
CANVAS = ["#3e3222", "#5e4c34", "#82704e", "#a69470", "#c8b892", "#e4d8b6"]     # bags, pouches, vest
BURLAP = ["#43301a", "#6a4c28", "#8e6a3a", "#b08a50", "#ccaa6c", "#e4c88e"]     # sacks
CLOTH_RED = ["#3e1412", "#66221c", "#8e3426", "#b24c32", "#d06e46", "#e89a6a"]  # rags, bandana
CLOTH_BLUE = ["#1c2436", "#2c3a54", "#405676", "#5c7898", "#86a2ba"]          # cloth scrap patch
CLOTH_WHITE = ["#8a8270", "#b2aa94", "#d4ccb4", "#ece6d2", "#fbf8ec"]         # bandage, labels
LEATHER = ["#2e1a10", "#4a2a18", "#6a3e22", "#8c5630", "#ae7444", "#cc965e"]    # boots, straps
RUBBER = ["#151517", "#222226", "#323238", "#46464c", "#62626a"]               # tyre, seals, mask
PLASTIC_TEAL = ["#123a3e", "#1e5a5c", "#2e7e7a", "#4aa49a", "#7ccab8", "#c0eedc"]  # crushed bottle
PLASTIC_RED = ["#4a1010", "#781a18", "#a82a22", "#d0463a", "#ec7a62"]          # caps, tags, shells
HAZMAT = ["#4e3c0c", "#7a5e14", "#a88a1e", "#d0b030", "#ecd25a", "#fbeca0"]     # rad suit yellow
OLIVE_DRAB = ["#262a14", "#3a401e", "#525a2a", "#6c7438", "#8a904c", "#aaae6a"] # ration tins, gear

# -- glass & liquids ----------------------------------------------------------------------------
GLASS = ["#2a4448", "#3e6a6e", "#68a0a0", "#a2d0c8", "#d8f2ea", "#f4fffa"]      # clear bottle glass
GLASS_BROWN = ["#2a1206", "#46220c", "#6a3814", "#90521e", "#b8763a", "#e0a868"]  # rotgut bottle
GLASS_GREEN = ["#14301c", "#22482a", "#346a3c", "#4e8e52", "#7cb874", "#bce0a8"]  # wine bottle
WATER = ["#1d3b4f", "#2c5468", "#3c6f86", "#4f8aa1", "#6aa6b8", "#9cc8d2", "#d6ecee"]  # == palette water
MILK = ["#9c9484", "#c4bcaa", "#e2dccc", "#f2eee2", "#fdfbf4"]                 # milk, cream
GOAT_MILK = ["#8e9a7a", "#b4c09a", "#d4dcb8", "#e8eed2", "#f8fbec"]            # faint green-tinted milk
HONEY = ["#6a3204", "#9a520a", "#c87a10", "#eba224", "#ffc948", "#ffe48a"]      # honey, sap (amber)
SAP = ["#5a2604", "#8a4206", "#b8620e", "#e08a1e", "#f8b440", "#ffe08a"]        # tree sap droplet
JAM = ["#3e0614", "#640c1e", "#8e1626", "#b82a34", "#dc4e4e", "#f48a7a"]        # berry jam
BRINE = ["#5a5420", "#80782c", "#a89c3e", "#ccbe5c", "#e6da88"]               # pickle brine
CHEM_BLUE = ["#1a1840", "#2a2a6a", "#40449a", "#5e6ac4", "#8e9ce4", "#c8d2f8"]  # pre-war reagent
BIO_MURK = ["#22200e", "#3a3a16", "#545424", "#6e6c30", "#8c8640", "#aca45a"]   # bio sample (murky)
GLOW_SOFT = ["#5e7a1c", "#8aa82c", "#b8d44a", "#dcec7a", "#f4fab8", "#fffde6"]  # glow melon/wine (cozy glow, NOT rad)
GLOWCAP = ["#1c3a4a", "#22586a", "#2e7e8a", "#4aa8a8", "#86d4c4", "#c8f4e2"]    # glowcap mushroom (teal, cozy)
COFFEE = ["#1c0e06", "#2e180c", "#462616", "#603820", "#7e4e2e"]              # coffee, chocolate
CHOCO = ["#26120a", "#3c1e10", "#562c18", "#723e22", "#90542e", "#ae6c3e"]       # chocolate bar
STEAM = ["#e8e0cc", "#fbf6e8"]                                                  # steam wisps (after outline)

# -- food ---------------------------------------------------------------------------------------
BREAD = ["#6e3c10", "#9a5a18", "#c88224", "#e8aa3a", "#f8cc66", "#ffe6a0"]       # corn bread crust/crumb
CHEESE = ["#7a4a0a", "#b07414", "#dca22a", "#f4c84a", "#ffe282", "#fff4c4"]     # cheese wedge
JERKY = ["#2a0c08", "#481610", "#6a2418", "#8c3824", "#ac5434"]                # dried meat
STEW = ["#3a1a0a", "#5a2c12", "#7c421c", "#9c5c2a", "#bc7a3e"]                 # stew broth
CHILI = ["#3e0c08", "#661810", "#902818", "#b84020", "#d86a36"]                # chili
SOUP_ORANGE = ["#7a3008", "#a8480e", "#d46a16", "#f09430", "#ffbe5a", "#ffe08e"]  # pumpkin soup
BEANS = ["#3e140a", "#621f10", "#8a3018", "#ae4826", "#cc683a"]                # beans in tomato sauce
EGG_BROWN = ["#6a3a1c", "#94562c", "#b8763e", "#d49a5c", "#ecc08a", "#fbe2bc"]  # brown egg shell
EGG_MUTANT = ["#5a4a34", "#80704e", "#a49668", "#c4b886", "#ded4a8", "#f4ecd0"]  # pale speckled mutant egg
MEAT_RED = ["#4a0e10", "#721a1a", "#9a2c26", "#c04a3a", "#dc7258"]              # meat
POTATO_CUBE = ["#8a5a1c", "#b8802a", "#dca844", "#f2ca6a", "#ffe8a0"]          # fried potato cubes

# -- ceramics / bowls / misc --------------------------------------------------------------------
BOWL = ["#3e2414", "#5c3a20", "#7e5430", "#9e6e40", "#bc8a54", "#d8a86c"]       # wooden bowl
CERAMIC = ["#6a5446", "#968070", "#bca898", "#dccabc", "#f2e6da"]             # mug / plate
SKILLET = ["#16161a", "#24242a", "#36363e", "#4c4c56", "#6a6a74"]              # cast-iron pan
CASE_RED = ["#3a100c", "#5e1c14", "#86301e", "#a8442a", "#c8623e", "#e08a5e"]  # medkit (rust-red, not corporate red)
ORANGE_MED = ["#6a2406", "#9a3a0a", "#c85a12", "#ec8022", "#ffa848", "#ffd08a"]  # purifier
CIRCUIT = ["#0e2a1a", "#16422a", "#22603a", "#32804a", "#4ea260", "#86c888"]    # circuit board green
SOLDER = ["#7e7a6a", "#a8a490", "#d2ccb4"]                                     # traces / pads
CRYSTAL_ICE = ["#2a4a66", "#4a7496", "#74a2c2", "#a6cce0", "#d8eef6", "#ffffff"]  # crystal moss / frost
STONE = P.STONE_RAMP                                                            # stones (6)
STONE_WARM = ["#3e3532", "#5a4e48", "#786a60", "#988a7c", "#b8aa98", "#d6cab6"]  # warmer stone (reference look)
STONE_LILAC = ["#3a3440", "#544c5c", "#706878", "#8e8698", "#b2acba", "#d6d2dc"]  # PixelLab stone icon look
SOIL = P.SOIL_RAMP                                                              # dirt, compost
ASH = ["#2a2622", "#423c36", "#5c5347", "#7a7062", "#9a907e"]                  # ash, soot

# -- plant colours (crops are coloured from data/crops.json at build time) ----------------------
LEAF = ["#1f3a22", "#2e5430", "#3f6e36", "#56883e", "#74a24a", "#9cbe5e"]       # produce leaves / calyx
LEAF_FRESH = P.GRASS_SPRING_RAMP                                                # bright young leaves
LEAF_DRY = ["#3a2a12", "#5a4220", "#7a5c2e", "#98763c", "#b8944e", "#d4b06a"]   # withered crops
STEM = ["#2a3a16", "#3e5420", "#56702c", "#728c3a", "#92a84c"]                 # stems
FLOWER_WHITE = ["#8c8478", "#b8b0a2", "#ddd6c8", "#f4efe4", "#ffffff"]          # potato blossom, dandelion fluff
FLOWER_YELLOW = ["#8a5a0a", "#c08a14", "#e8b424", "#ffd448", "#fff08a"]         # tomato/pepper/squash blossoms
FLOWER_PINK = ["#7a3a5a", "#a8587c", "#d07c9e", "#f3acb7", "#ffd6dc"]           # spring blossom (palette pink)

# -- glow accent: hazard only (ruins items) -----------------------------------------------------
RAD = ["#123a12", "#1e5a1c", P.RAD_GLOW_DEEP, "#5cc436", P.RAD_GLOW, "#d4ffa8"]  # rad crystal, rad hazard
